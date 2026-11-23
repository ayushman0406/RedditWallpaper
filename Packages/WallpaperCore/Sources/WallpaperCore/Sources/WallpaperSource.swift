import Foundation

public enum SortOrder: String, Codable, Sendable, CaseIterable, Hashable {
    case top
    case new
    case random

    public var displayName: String {
        switch self {
        case .top: "Top"
        case .new: "New"
        case .random: "Random"
        }
    }
}

/// What one source is asked for: a scope (everything, one interest, or a
/// search), a kind, an order and a page.
public struct SourceQuery: Sendable, Hashable {
    public enum Scope: Sendable, Hashable {
        case general
        case interest(Interest)
        case search(String)
    }

    public var scope: Scope
    public var kind: MediaKind
    public var sort: SortOrder
    public var page: Int
    public var minWidth: Int
    public var minHeight: Int
    public var seed: String

    public init(
        scope: Scope,
        kind: MediaKind,
        sort: SortOrder,
        page: Int = 1,
        minWidth: Int = 1920,
        minHeight: Int = 1080,
        seed: String = "w4llp4"
    ) {
        self.scope = scope
        self.kind = kind
        self.sort = sort
        self.page = page
        self.minWidth = minWidth
        self.minHeight = minHeight
        self.seed = seed
    }

    public var interestID: String? {
        if case let .interest(interest) = scope { return interest.id }
        return nil
    }

    /// Free text to search for: the search itself, or the interest's term for this page.
    var searchText: String? {
        switch scope {
        case .general: nil
        case .search(let text): text
        case .interest(let interest): interest.searchTerm(forPage: page)
        }
    }

    /// The page number to send to a searchable source (interests rotate terms).
    var sourcePage: Int {
        if case let .interest(interest) = scope { return interest.sourcePage(forPage: page) }
        return max(page, 1)
    }
}

/// A wallpaper provider. Building requests and parsing responses are pure,
/// so each source is tested without a network.
public protocol WallpaperSource: Sendable {
    var id: SourceID { get }
    func supports(_ query: SourceQuery) -> Bool
    func makeRequest(for query: SourceQuery) throws -> URLRequest
    func parse(_ data: Data, for query: SourceQuery) throws -> [Wallpaper]
    /// A short explanation of a failed HTTP response.
    func errorMessage(status: Int, data: Data) -> String
}

extension WallpaperSource {
    public func errorMessage(status: Int, data: Data) -> String {
        switch status {
        case 401, 403:
            return "The API key was rejected."
        case 429:
            return "Rate limit reached. Try again in a few minutes."
        default:
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = (json["message"] ?? json["error"]) as? String {
                return "HTTP \(status): \(message)"
            }
            return "HTTP \(status)"
        }
    }
}

public enum SourceError: Error, Equatable, Sendable {
    case badStatus(SourceID, Int, String)
    case decoding(SourceID, String)
    case transport(SourceID, String)

    public var source: SourceID {
        switch self {
        case .badStatus(let source, _, _), .decoding(let source, _), .transport(let source, _):
            source
        }
    }

    /// Readable text for the UI, naming the source.
    public var message: String {
        switch self {
        case let .badStatus(source, _, text):
            "\(source.displayName): \(text)"
        case let .decoding(source, _):
            "\(source.displayName) sent a response this app couldn't read."
        case let .transport(source, text):
            "\(source.displayName): \(text)"
        }
    }
}

enum RequestBuilder {
    static func url(_ base: String, _ items: [(String, String)]) throws -> URL {
        let query = QueryString.encode(items)
        guard let url = URL(string: query.isEmpty ? base : "\(base)?\(query)") else {
            throw URLError(.badURL)
        }
        return url
    }

    static func request(_ url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("RedditWallpaper/2.0 (macOS)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 20
        return request
    }
}
