import Foundation
import Testing
@testable import WallpaperCore

@Suite struct AerialManifestEditorTests {
    let movie = URL(fileURLWithPath: "/Users/me/Library/Application Support/com.apple.wallpaper/aerials/videos/X.mov")
    let preview = URL(fileURLWithPath: "/Users/me/Library/Application Support/com.apple.wallpaper/aerials/videos/X-preview.png")

    func assets(_ manifest: [String: Any]) -> [[String: Any]] { manifest["assets"] as? [[String: Any]] ?? [] }
    func categories(_ manifest: [String: Any]) -> [[String: Any]] { manifest["categories"] as? [[String: Any]] ?? [] }

    func appleManifest() -> [String: Any] {
        [
            "version": 1,
            "assets": [["id": "APPLE-1", "accessibilityLabel": "Tahoe Day",
                        "url-4K-SDR-240FPS": "https://sylvan.apple.com/x.mov", "categories": ["APPLE-CAT"]]],
            "categories": [["id": "APPLE-CAT", "localizedNameKey": "Landscape"]],
        ]
    }

    @Test func registersIntoEmptyManifest() {
        let manifest = AerialManifestEditor.registering(title: "Supra Night", movieURL: movie, previewURL: preview, in: nil)
        #expect(manifest["version"] as? Int == 1)
        let first = assets(manifest).first
        #expect(first?["id"] as? String == AerialManifestEditor.assetID)
        #expect(first?["url-4K-SDR-240FPS"] as? String == movie.absoluteString)
        #expect(first?["previewImage"] as? String == preview.absoluteString)
        #expect(first?["accessibilityLabel"] as? String == "Supra Night")
        #expect(first?["categories"] as? [String] == [AerialManifestEditor.categoryID])
        #expect(first?["subcategories"] as? [String] == [AerialManifestEditor.subcategoryID])
        #expect(first?["includeInShuffle"] as? Bool == false)
        #expect(categories(manifest).first?["id"] as? String == AerialManifestEditor.categoryID)
        #expect(categories(manifest).first?["localizedNameKey"] as? String == "RedditWallpaper")
    }

    @Test func reRegisteringReplacesInsteadOfDuplicating() {
        let once = AerialManifestEditor.registering(title: "One", movieURL: movie, previewURL: preview, in: appleManifest())
        let twice = AerialManifestEditor.registering(title: "Two", movieURL: movie, previewURL: preview, in: once)
        let ours = assets(twice).filter { $0["id"] as? String == AerialManifestEditor.assetID }
        #expect(ours.count == 1)
        #expect(ours.first?["accessibilityLabel"] as? String == "Two")
        #expect(categories(twice).filter { $0["id"] as? String == AerialManifestEditor.categoryID }.count == 1)
    }

    @Test func preservesAppleAssets() {
        let manifest = AerialManifestEditor.registering(title: "One", movieURL: movie, previewURL: preview, in: appleManifest())
        #expect(assets(manifest).contains { $0["id"] as? String == "APPLE-1" })
        #expect(categories(manifest).contains { $0["id"] as? String == "APPLE-CAT" })
        #expect(assets(manifest).count == 2)
    }

    @Test func removingOurEntriesKeepsAppleAssets() {
        let manifest = AerialManifestEditor.registering(title: "One", movieURL: movie, previewURL: preview, in: appleManifest())
        let cleaned = AerialManifestEditor.removingOurEntries(from: manifest)
        #expect(assets(cleaned).map { $0["id"] as? String } == ["APPLE-1"])
        #expect(categories(cleaned).map { $0["id"] as? String } == ["APPLE-CAT"])
    }
}
