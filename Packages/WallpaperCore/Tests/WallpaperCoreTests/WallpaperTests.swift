import Foundation
import Testing
@testable import WallpaperCore

@Suite struct WallpaperTests {
    private func make(
        width: Int?, height: Int?, kind: MediaKind = .photo,
        media: String = "https://example.com/a.jpg"
    ) -> Wallpaper {
        Wallpaper(
            id: "test:1", source: .wallhaven, kind: kind, title: "T",
            thumbnailURL: URL(string: "https://example.com/t.jpg")!,
            mediaURL: URL(string: media)!, width: width, height: height)
    }

    @Test func aspectRatioAndBadge() throws {
        let wallpaper = make(width: 3840, height: 2160)
        let ratio = try #require(wallpaper.aspectRatio)
        #expect(abs(ratio - 1.7777) < 0.001)
        #expect(wallpaper.qualityBadge == "4K")
        #expect(wallpaper.resolutionLabel == "3840 × 2160")
        #expect(make(width: 7680, height: 4320).qualityBadge == "8K")
        #expect(make(width: 5120, height: 2880).qualityBadge == "5K")
        #expect(make(width: 2560, height: 1440).qualityBadge == "QHD")
        #expect(make(width: 1920, height: 1080).qualityBadge == "HD")
        #expect(make(width: 1280, height: 720).qualityBadge == nil)
        #expect(make(width: nil, height: nil).aspectRatio == nil)
        #expect(make(width: nil, height: nil).resolutionLabel == nil)
    }

    @Test func fileExtensionFromURLOrKindDefault() {
        #expect(make(width: nil, height: nil, media: "https://w.wallhaven.cc/full/72/a.PNG").preferredFileExtension == "png")
        #expect(make(width: nil, height: nil, media: "https://www.bing.com/th?id=x").preferredFileExtension == "jpg")
        #expect(make(width: nil, height: nil, kind: .video, media: "https://example.com/video/123").preferredFileExtension == "mp4")
        #expect(make(width: nil, height: nil, kind: .video, media: "https://example.com/v.mov").preferredFileExtension == "mov")
    }

    @Test func codableRoundTrip() throws {
        var wallpaper = make(width: 1920, height: 1080)
        wallpaper.interestIDs = ["cars"]
        let data = try JSONEncoder().encode(wallpaper)
        let decoded = try JSONDecoder().decode(Wallpaper.self, from: data)
        #expect(decoded == wallpaper)
    }
}
