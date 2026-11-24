import Foundation
import Testing
@testable import WallpaperCore

@Suite struct PexelsSourceTests {
    let source = PexelsSource(apiKey: "test-key")
    let surfing = InterestCatalog.preset(id: "surfing")!

    @Test func unsupportedWithoutKey() {
        #expect(!PexelsSource(apiKey: nil).supports(SourceQuery(scope: .general, kind: .photo, sort: .top)))
        #expect(!PexelsSource(apiKey: "  ").supports(SourceQuery(scope: .general, kind: .video, sort: .top)))
        #expect(source.supports(SourceQuery(scope: .interest(surfing), kind: .video, sort: .top)))
    }

    @Test func photoSearchRequest() throws {
        let request = try source.makeRequest(for: SourceQuery(scope: .interest(surfing), kind: .photo, sort: .top, page: 1))
        #expect(request.value(forHTTPHeaderField: "Authorization") == "test-key")
        #expect(request.url?.host == "api.pexels.com")
        #expect(request.url?.path == "/v1/search")
        let query = queryItems(request)
        #expect(query["query"] == "surfing")
        #expect(query["orientation"] == "landscape")
        #expect(query["size"] == "medium")
        #expect(query["per_page"] == "30")
        #expect(query["page"] == "1")
    }

    @Test func videoSearchUsesV1VideosPath() throws {
        let request = try source.makeRequest(for: SourceQuery(scope: .search("Porsche 911"), kind: .video, sort: .top, page: 3))
        #expect(request.url?.path == "/v1/videos/search")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "test-key")
        let query = queryItems(request)
        #expect(query["query"] == "Porsche 911")
        #expect(query["per_page"] == "20")
        #expect(query["page"] == "3")
    }

    @Test func generalUsesCuratedAndPopular() throws {
        let curated = try source.makeRequest(for: SourceQuery(scope: .general, kind: .photo, sort: .top))
        #expect(curated.url?.path == "/v1/curated")
        let popular = try source.makeRequest(for: SourceQuery(scope: .general, kind: .video, sort: .top))
        #expect(popular.url?.path == "/v1/videos/popular")
        #expect(queryItems(popular)["min_width"] == "1920")
    }

    @Test func parsesPhotos() throws {
        let query = SourceQuery(scope: .interest(surfing), kind: .photo, sort: .top)
        let items = try source.parse(Fixture.data("pexels-photos"), for: query)
        #expect(items.count == 2)
        let first = items[0]
        #expect(first.id == "pexels:photo-2014422")
        #expect(first.kind == .photo)
        #expect(first.source == .pexels)
        #expect(first.mediaURL.absoluteString == "https://images.pexels.com/photos/2014422/pexels-photo-2014422.jpeg")
        #expect(first.thumbnailURL.absoluteString.hasSuffix("h=350"))
        #expect(first.author == "Joey Farina")
        #expect(first.title == "Red sports car on a mountain road")
        #expect(first.width == 6000)
        #expect(first.height == 4000)
        #expect(first.pageURL?.absoluteString == "https://www.pexels.com/photo/red-sports-car-2014422/")
        #expect(items[1].title == "Photo by Ana Ruiz")
    }

    @Test func parsesVideosPicksBestFile() throws {
        let query = SourceQuery(scope: .interest(surfing), kind: .video, sort: .top)
        let items = try source.parse(Fixture.data("pexels-videos"), for: query)
        #expect(items.count == 2)
        let first = items[0]
        #expect(first.id == "pexels:video-1234567")
        #expect(first.kind == .video)
        #expect(first.mediaURL.absoluteString == "https://videos.pexels.com/video-files/1234567/uhd_3840_2160_25fps.mp4")
        #expect(first.thumbnailURL.absoluteString == "https://images.pexels.com/videos/1234567/pictures/preview-0.jpg")
        #expect(first.width == 3840)
        #expect(first.height == 2160)
        #expect(first.duration == 18)
        #expect(first.title == "Aerial view of surfers")
        #expect(first.author == "Jane Doe")
        #expect(items[1].title == "Video by Sam Lee")

        let hdOnly = try PexelsSource(apiKey: "k", maxVideoWidth: 1920).parse(Fixture.data("pexels-videos"), for: query)
        #expect(hdOnly[0].mediaURL.absoluteString == "https://videos.pexels.com/video-files/1234567/hd_1920_1080_25fps.mp4")
    }

    @Test func bestVideoFileFallsBackToSmallest() {
        let files = [
            PexelsSource.VideoFile(quality: "uhd", fileType: "video/mp4", width: 3840, height: 2160, link: URL(string: "https://x.test/4k.mp4")!),
            PexelsSource.VideoFile(quality: "hd", fileType: "video/mp4", width: 2560, height: 1440, link: URL(string: "https://x.test/qhd.mp4")!),
        ]
        #expect(PexelsSource.bestVideoFile(files, maxWidth: 1920)?.width == 2560)
    }

    @Test func titleFromSlug() {
        #expect(PexelsSource.title(fromPageURL: URL(string: "https://www.pexels.com/video/aerial-view-of-surfers-1234567/")!) == "Aerial view of surfers")
        #expect(PexelsSource.title(fromPageURL: URL(string: "https://www.pexels.com/video/7654321/")!) == nil)
    }

    @Test func rejectedKeyMessage() {
        #expect(source.errorMessage(status: 401, data: Data()) == "The API key was rejected.")
        #expect(source.errorMessage(status: 429, data: Data()) == "Rate limit reached. Try again in a few minutes.")
    }
}
