import Foundation

/// One page of a feed: which interests (or a search), photos or videos,
/// the order, and which sources may answer.
public struct FeedRequest: Sendable, Hashable {
    public var scopes: [SourceQuery.Scope]
    public var kind: MediaKind
    public var sort: SortOrder
    public var page: Int
    public var minWidth: Int
    public var minHeight: Int
    public var seed: String
    public var excludedIDs: Set<String>
    public var enabledSources: Set<SourceID>

    public init(
        scopes: [SourceQuery.Scope],
        kind: MediaKind,
        sort: SortOrder,
        page: Int = 1,
        minWidth: Int = 1920,
        minHeight: Int = 1080,
        seed: String = "w4llp4",
        excludedIDs: Set<String> = [],
        enabledSources: Set<SourceID> = Set(SourceID.allCases)
    ) {
        self.scopes = scopes
        self.kind = kind
        self.sort = sort
        self.page = page
        self.minWidth = minWidth
        self.minHeight = minHeight
        self.seed = seed
        self.excludedIDs = excludedIDs
        self.enabledSources = enabledSources
    }
}

public struct FeedPage: Sendable {
    public var items: [Wallpaper]
    /// Sources that failed. Items from the others are still returned.
    public var errors: [SourceError]
    /// True when no source returned anything for this page.
    public var isExhausted: Bool

    public init(items: [Wallpaper], errors: [SourceError], isExhausted: Bool) {
        self.items = items
        self.errors = errors
        self.isExhausted = isExhausted
    }
}

/// Asks every enabled source about every interest at once, then mixes the
/// answers so no single interest or source floods the page.
public struct FeedService: Sendable {
    let sources: [any WallpaperSource]
    let client: any HTTPClient

    public init(sources: [any WallpaperSource], client: any HTTPClient) {
        self.sources = sources
        self.client = client
    }

    private struct Job: Sendable {
        let index: Int
        let scopeIndex: Int
        let source: any WallpaperSource
        let query: SourceQuery
    }

    public func load(_ request: FeedRequest) async -> FeedPage {
        var jobs: [Job] = []
        for (scopeIndex, scope) in request.scopes.enumerated() {
            let query = SourceQuery(
                scope: scope, kind: request.kind, sort: request.sort, page: request.page,
                minWidth: request.minWidth, minHeight: request.minHeight, seed: request.seed)
            for source in sources where request.enabledSources.contains(source.id) && source.supports(query) {
                jobs.append(Job(index: jobs.count, scopeIndex: scopeIndex, source: source, query: query))
            }
        }
        guard !jobs.isEmpty else { return FeedPage(items: [], errors: [], isExhausted: true) }

        let client = self.client
        var results = [Result<[Wallpaper], SourceError>?](repeating: nil, count: jobs.count)
        await withTaskGroup(of: (Int, Result<[Wallpaper], SourceError>).self) { group in
            for job in jobs {
                group.addTask {
                    (job.index, await Self.run(job.source, job.query, client: client))
                }
            }
            for await (index, result) in group {
                results[index] = result
            }
        }

        var listsByScope = [[[Wallpaper]]](repeating: [], count: request.scopes.count)
        var errors: [SourceError] = []
        for job in jobs {
            switch results[job.index] {
            case .success(var items)?:
                if let interestID = job.query.interestID {
                    for index in items.indices where !items[index].interestIDs.contains(interestID) {
                        items[index].interestIDs.append(interestID)
                    }
                }
                listsByScope[job.scopeIndex].append(items)
            case .failure(let error)?:
                errors.append(error)
            case nil:
                break
            }
        }

        let gotAnything = listsByScope.contains { lists in lists.contains { !$0.isEmpty } }
        var items = Self.dedupe(Self.interleave(listsByScope.map(Self.interleave)))
        items = items.filter {
            !request.excludedIDs.contains($0.id)
                && Self.isSuitable($0, minWidth: request.minWidth, minHeight: request.minHeight)
        }
        if request.sort == .random {
            items = items.seededShuffle(seed: "\(request.seed)-\(request.page)")
        }
        return FeedPage(items: items, errors: errors, isExhausted: !gotAnything)
    }

    /// Round-robin merge: first of each list, then second of each, …
    public static func interleave(_ lists: [[Wallpaper]]) -> [Wallpaper] {
        let longest = lists.map(\.count).max() ?? 0
        var result: [Wallpaper] = []
        result.reserveCapacity(lists.reduce(0) { $0 + $1.count })
        for position in 0..<longest {
            for list in lists where position < list.count {
                result.append(list[position])
            }
        }
        return result
    }

    /// Desktop-sized and landscape when the size is known; unknown sizes pass.
    public static func isSuitable(_ wallpaper: Wallpaper, minWidth: Int, minHeight: Int) -> Bool {
        guard let width = wallpaper.width, let height = wallpaper.height, height > 0 else { return true }
        return Double(width) / Double(height) >= 1.2 && width >= minWidth && height >= minHeight
    }

    /// Keeps the first of each id (merging the interests that found it) and
    /// drops later items that point at the same file.
    static func dedupe(_ items: [Wallpaper]) -> [Wallpaper] {
        var result: [Wallpaper] = []
        var positionByID: [String: Int] = [:]
        var seenMedia: Set<URL> = []
        for item in items {
            if let position = positionByID[item.id] {
                for interestID in item.interestIDs where !result[position].interestIDs.contains(interestID) {
                    result[position].interestIDs.append(interestID)
                }
                continue
            }
            guard !seenMedia.contains(item.mediaURL) else { continue }
            positionByID[item.id] = result.count
            seenMedia.insert(item.mediaURL)
            result.append(item)
        }
        return result
    }

    static func run(
        _ source: any WallpaperSource, _ query: SourceQuery, client: any HTTPClient
    ) async -> Result<[Wallpaper], SourceError> {
        let request: URLRequest
        do {
            request = try source.makeRequest(for: query)
        } catch {
            return .failure(.transport(source.id, describe(error)))
        }
        let response: (Data, HTTPURLResponse)
        do {
            response = try await client.data(for: request)
        } catch {
            return .failure(.transport(source.id, describe(error)))
        }
        let (data, http) = response
        guard (200..<300).contains(http.statusCode) else {
            return .failure(.badStatus(source.id, http.statusCode, source.errorMessage(status: http.statusCode, data: data)))
        }
        do {
            return .success(try source.parse(data, for: query))
        } catch {
            return .failure(.decoding(source.id, String(describing: error)))
        }
    }

    static func describe(_ error: Error) -> String {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return "You're offline."
            case .timedOut:
                return "The request timed out."
            case .cannotFindHost, .dnsLookupFailed:
                return "The server couldn't be reached."
            default:
                break
            }
        }
        return error.localizedDescription
    }
}
