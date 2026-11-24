import Foundation
import Testing
@testable import WallpaperCore

@Suite struct WallhavenSourceTests {
    let source = WallhavenSource()
    let onePiece = InterestCatalog.preset(id: "onePiece")!

    @Test func topRequestForInterest() throws {
        let request = try source.makeRequest(for: SourceQuery(scope: .interest(onePiece), kind: .photo, sort: .top, page: 1))
        #expect(request.url?.host == "wallhaven.cc")
        #expect(request.url?.path == "/api/v1/search")
        let query = queryItems(request)
        #expect(query["q"] == "one piece")
        #expect(query["categories"] == "110")
        #expect(query["purity"] == "100")
        #expect(query["sorting"] == "favorites")
        #expect(query["atleast"] == "1920x1080")
        #expect(query["page"] == "1")
        #expect(request.url?.absoluteString.contains("q=one%20piece") == true)
    }

    @Test func generalTopUsesToplist() throws {
        let query = queryItems(try source.makeRequest(for: SourceQuery(scope: .general, kind: .photo, sort: .top)))
        #expect(query["sorting"] == "toplist")
        #expect(query["topRange"] == "1M")
        #expect(query["categories"] == "111")
        #expect(query["q"] == nil)
    }

    @Test func newUsesDateAdded() throws {
        let query = queryItems(try source.makeRequest(for: SourceQuery(scope: .interest(onePiece), kind: .photo, sort: .new)))
        #expect(query["sorting"] == "date_added")
    }

    @Test func randomIncludesSixCharSeed() throws {
        let request = try source.makeRequest(for: SourceQuery(scope: .general, kind: .photo, sort: .random, seed: "my seed!"))
        let query = queryItems(request)
        #expect(query["sorting"] == "random")
        let seed = try #require(query["seed"])
        #expect(seed.count == 6)
        #expect(seed.allSatisfy { $0.isLetter || $0.isNumber })
    }

    @Test func searchTextIsEncoded() throws {
        let request = try source.makeRequest(for: SourceQuery(scope: .search("Tom & Jerry"), kind: .photo, sort: .top))
        #expect(request.url?.absoluteString.contains("q=Tom%20%26%20Jerry") == true)
    }

    @Test func secondPageUsesSecondSearchTerm() throws {
        let query = queryItems(try source.makeRequest(for: SourceQuery(scope: .interest(onePiece), kind: .photo, sort: .top, page: 2)))
        #expect(query["q"] == "monkey d. luffy")
        #expect(query["page"] == "1")
    }

    @Test func unsupportedForVideo() {
        #expect(!source.supports(SourceQuery(scope: .general, kind: .video, sort: .top)))
        #expect(source.supports(SourceQuery(scope: .search("cars"), kind: .photo, sort: .top)))
    }

    @Test func parsesFixture() throws {
        let query = SourceQuery(scope: .interest(onePiece), kind: .photo, sort: .top)
        let items = try source.parse(Fixture.data("wallhaven-onepiece"), for: query)
        #expect(items.count == 3)
        let first = try #require(items.first)
        #expect(first.id == "wallhaven:72lej9")
        #expect(first.source == .wallhaven)
        #expect(first.mediaURL.absoluteString == "https://w.wallhaven.cc/full/72/wallhaven-72lej9.png")
        #expect(first.thumbnailURL.absoluteString == "https://th.wallhaven.cc/lg/72/72lej9.jpg")
        #expect(first.width == 7680)
        #expect(first.height == 4320)
        #expect(first.score == 847)
        #expect(first.title == "One Piece wallpaper")
        #expect(first.pageURL?.absoluteString == "https://wallhaven.cc/w/72lej9")
        #expect(first.createdAt != nil)
    }

    @Test func dropsNonSFW() throws {
        let json = """
        {"data":[
         {"id":"aaa111","url":"https://wallhaven.cc/w/aaa111","purity":"sketchy","category":"general","dimension_x":1920,"dimension_y":1080,"favorites":1,"created_at":"2024-01-01 00:00:00","path":"https://w.wallhaven.cc/full/aa/wallhaven-aaa111.jpg","thumbs":{"large":"https://th.wallhaven.cc/lg/aa/aaa111.jpg"}},
         {"id":"bbb222","url":"https://wallhaven.cc/w/bbb222","purity":"sfw","category":"general","dimension_x":1920,"dimension_y":1080,"favorites":2,"created_at":"2024-01-01 00:00:00","path":"https://w.wallhaven.cc/full/bb/wallhaven-bbb222.jpg","thumbs":{"large":"https://th.wallhaven.cc/lg/bb/bbb222.jpg"}}],
         "meta":{"current_page":1,"last_page":1}}
        """
        let items = try source.parse(Data(json.utf8), for: SourceQuery(scope: .general, kind: .photo, sort: .top))
        #expect(items.map(\.id) == ["wallhaven:bbb222"])
        #expect(items.first?.title == "Wallhaven wallpaper")
    }
}
