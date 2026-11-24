import Foundation
import Testing
@testable import WallpaperCore

/// Records requests and answers by host: a status code, or a thrown error.
final class MockHTTPClient: HTTPClient, @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [URL] = []
    let statusByHost: [String: Int]
    let failingHosts: Set<String>

    init(statusByHost: [String: Int] = [:], failingHosts: Set<String> = []) {
        self.statusByHost = statusByHost
        self.failingHosts = failingHosts
    }

    var requestedHosts: [String] { lock.withLock { recorded.compactMap(\.host) } }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let url = try #require(request.url)
        lock.withLock { recorded.append(url) }
        if failingHosts.contains(url.host ?? "") { throw URLError(.notConnectedToInternet) }
        let status = statusByHost[url.host ?? ""] ?? 200
        let response = try #require(HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil))
        return (Data(), response)
    }
}

/// A source whose parse returns canned wallpapers for each query.
struct StubSource: WallpaperSource {
    let id: SourceID
    let host: String
    var kinds: Set<MediaKind> = [.photo]
    let items: @Sendable (SourceQuery) -> [Wallpaper]

    func supports(_ query: SourceQuery) -> Bool { kinds.contains(query.kind) }

    func makeRequest(for query: SourceQuery) throws -> URLRequest {
        URLRequest(url: URL(string: "https://\(host)/\(query.interestID ?? "general")?page=\(query.page)")!)
    }

    func parse(_ data: Data, for query: SourceQuery) throws -> [Wallpaper] { items(query) }
}

func wallpaper(
    _ id: String, source: SourceID = .wallhaven, width: Int? = 3840, height: Int? = 2160, media: String? = nil
) -> Wallpaper {
    Wallpaper(
        id: id, source: source, kind: .photo, title: id,
        thumbnailURL: URL(string: "https://img.test/\(id)-thumb.jpg")!,
        mediaURL: URL(string: media ?? "https://img.test/\(id).jpg")!,
        width: width, height: height)
}

@Suite struct FeedServiceTests {
    let cars = InterestCatalog.preset(id: "cars")!
    let surfing = InterestCatalog.preset(id: "surfing")!

    @Test func interleavesRoundRobin() {
        let a = [wallpaper("a1"), wallpaper("a2"), wallpaper("a3")]
        let b = [wallpaper("b1")]
        #expect(FeedService.interleave([a, b]).map(\.id) == ["a1", "b1", "a2", "a3"])
    }

    @Test func mergesInterestsAndTagsItems() async {
        let source = StubSource(id: .wallhaven, host: "a.test") { query in
            let key = query.interestID ?? "general"
            return [wallpaper("\(key)-1"), wallpaper("\(key)-2")]
        }
        let service = FeedService(sources: [source], client: MockHTTPClient())
        let page = await service.load(FeedRequest(scopes: [.interest(cars), .interest(surfing)], kind: .photo, sort: .top))
        #expect(page.items.map(\.id) == ["cars-1", "surfing-1", "cars-2", "surfing-2"])
        #expect(page.items.first?.interestIDs == ["cars"])
        #expect(page.items[1].interestIDs == ["surfing"])
        #expect(page.errors.isEmpty)
        #expect(!page.isExhausted)
    }

    @Test func dedupesByIDAndMediaURL() async {
        let first = StubSource(id: .wallhaven, host: "a.test") { _ in [wallpaper("x", media: "https://img.test/same.jpg")] }
        let second = StubSource(id: .pexels, host: "b.test") { _ in
            [wallpaper("x"), wallpaper("y", media: "https://img.test/same.jpg"), wallpaper("z")]
        }
        let service = FeedService(sources: [first, second], client: MockHTTPClient())
        let page = await service.load(FeedRequest(scopes: [.general], kind: .photo, sort: .top))
        #expect(page.items.map(\.id) == ["x", "z"])
    }

    @Test func duplicateAcrossInterestsMergesTags() async {
        let source = StubSource(id: .wallhaven, host: "a.test") { _ in [wallpaper("shared")] }
        let service = FeedService(sources: [source], client: MockHTTPClient())
        let page = await service.load(FeedRequest(scopes: [.interest(cars), .interest(surfing)], kind: .photo, sort: .top))
        #expect(page.items.count == 1)
        #expect(page.items.first?.interestIDs == ["cars", "surfing"])
    }

    @Test func excludesBlockedIDs() async {
        let source = StubSource(id: .wallhaven, host: "a.test") { _ in [wallpaper("keep"), wallpaper("hidden")] }
        let service = FeedService(sources: [source], client: MockHTTPClient())
        var request = FeedRequest(scopes: [.general], kind: .photo, sort: .top)
        request.excludedIDs = ["hidden"]
        let page = await service.load(request)
        #expect(page.items.map(\.id) == ["keep"])
    }

    @Test func dropsPortraitAndSmallKnownSizes() async {
        let source = StubSource(id: .reddit, host: "a.test") { _ in
            [
                wallpaper("portrait", width: 1080, height: 1920),
                wallpaper("small", width: 1280, height: 720),
                wallpaper("unknown", width: nil, height: nil),
                wallpaper("good", width: 2560, height: 1440),
            ]
        }
        let service = FeedService(sources: [source], client: MockHTTPClient())
        let page = await service.load(FeedRequest(scopes: [.general], kind: .photo, sort: .top))
        #expect(page.items.map(\.id) == ["unknown", "good"])
    }

    @Test func skipsDisabledAndUnsupportedSources() async {
        let photos = StubSource(id: .wallhaven, host: "photos.test") { _ in [wallpaper("p")] }
        let disabled = StubSource(id: .reddit, host: "disabled.test") { _ in [wallpaper("r")] }
        let client = MockHTTPClient()
        let service = FeedService(sources: [photos, disabled], client: client)

        var request = FeedRequest(scopes: [.general], kind: .video, sort: .top)
        request.enabledSources = [.wallhaven]
        let page = await service.load(request)
        #expect(page.items.isEmpty)
        #expect(client.requestedHosts.isEmpty)

        request.kind = .photo
        let photoPage = await service.load(request)
        #expect(photoPage.items.map(\.id) == ["p"])
        #expect(client.requestedHosts == ["photos.test"])
    }

    @Test func partialFailureKeepsItemsAndReportsError() async {
        let good = StubSource(id: .wallhaven, host: "good.test") { _ in [wallpaper("ok")] }
        let bad = StubSource(id: .pexels, host: "bad.test") { _ in [wallpaper("never")] }
        let service = FeedService(sources: [good, bad], client: MockHTTPClient(statusByHost: ["bad.test": 500]))
        let page = await service.load(FeedRequest(scopes: [.general], kind: .photo, sort: .top))
        #expect(page.items.map(\.id) == ["ok"])
        #expect(page.errors.count == 1)
        guard case let .badStatus(source, status, _)? = page.errors.first else {
            Issue.record("expected badStatus, got \(page.errors)")
            return
        }
        #expect(source == .pexels)
        #expect(status == 500)
    }

    @Test func allSourcesFailingReturnsErrorsAndNoItems() async {
        let a = StubSource(id: .wallhaven, host: "a.test") { _ in [wallpaper("a")] }
        let b = StubSource(id: .reddit, host: "b.test") { _ in [wallpaper("b")] }
        let client = MockHTTPClient(failingHosts: ["a.test", "b.test"])
        let service = FeedService(sources: [a, b], client: client)
        let page = await service.load(FeedRequest(scopes: [.general], kind: .photo, sort: .top))
        #expect(page.items.isEmpty)
        #expect(page.isExhausted)
        #expect(page.errors.count == 2)
        #expect(page.errors.allSatisfy { error in
            if case .transport = error { return true } else { return false }
        })
        #expect(!page.errors[0].message.isEmpty)
    }

    // Regression: offline with several interests listed the same
    // "You're offline." once per interest.
    @Test func sameFailureAcrossInterestsIsReportedOnce() async {
        let source = StubSource(id: .wallhaven, host: "a.test") { _ in [wallpaper("a")] }
        let service = FeedService(sources: [source], client: MockHTTPClient(failingHosts: ["a.test"]))
        let page = await service.load(FeedRequest(
            scopes: [.interest(cars), .interest(surfing), .general], kind: .photo, sort: .top))
        #expect(page.errors.count == 1)
        #expect(page.errors.first?.source == .wallhaven)
    }

    @Test func randomSortIsDeterministic() async {
        let source = StubSource(id: .wallhaven, host: "a.test") { _ in (1...12).map { wallpaper("w\($0)") } }
        let service = FeedService(sources: [source], client: MockHTTPClient())
        let request = FeedRequest(scopes: [.general], kind: .photo, sort: .random, seed: "fixed")
        let first = await service.load(request)
        let second = await service.load(request)
        #expect(first.items.map(\.id) == second.items.map(\.id))
        #expect(first.items.map(\.id) != (1...12).map { "w\($0)" })
        #expect(Set(first.items.map(\.id)).count == 12)
    }
}
