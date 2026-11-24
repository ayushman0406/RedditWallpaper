import Foundation
import Testing
@testable import WallpaperCore

@Suite struct BingDailySourceTests {
    let source = BingDailySource()

    @Test func onlyGeneralPhotosOnFirstPage() {
        #expect(source.supports(SourceQuery(scope: .general, kind: .photo, sort: .top)))
        #expect(!source.supports(SourceQuery(scope: .general, kind: .photo, sort: .top, page: 2)))
        #expect(!source.supports(SourceQuery(scope: .general, kind: .video, sort: .top)))
        #expect(!source.supports(SourceQuery(scope: .interest(InterestCatalog.preset(id: "cars")!), kind: .photo, sort: .top)))
        #expect(!source.supports(SourceQuery(scope: .search("x"), kind: .photo, sort: .top)))
    }

    @Test func requestURL() throws {
        let request = try source.makeRequest(for: SourceQuery(scope: .general, kind: .photo, sort: .top))
        #expect(request.url?.absoluteString == "https://www.bing.com/HPImageArchive.aspx?format=js&idx=0&n=8&mkt=en-US")
    }

    @Test func parsesFixture() throws {
        let items = try source.parse(Fixture.data("bing"), for: SourceQuery(scope: .general, kind: .photo, sort: .top))
        #expect(items.count == 3)
        let first = items[0]
        #expect(first.id == "bing:20261123")
        #expect(first.source == .bing)
        #expect(first.mediaURL.absoluteString == "https://www.bing.com/th?id=OHR.FibonacciFern_EN-US6307771770_UHD.jpg")
        #expect(first.thumbnailURL.absoluteString == "https://www.bing.com/th?id=OHR.FibonacciFern_EN-US6307771770_800x480.jpg")
        #expect(first.title == "Geometry in nature")
        #expect(first.author == "Fiddlehead fern (© Reza Saputra/Getty Images)")
        #expect(first.width == 3840)
        #expect(first.height == 2160)
        #expect(first.createdAt != nil)
    }
}
