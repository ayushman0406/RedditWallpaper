import Foundation

/// Pure edits of the aerial list
/// (`~/Library/Application Support/com.apple.wallpaper/aerials/manifest/entries.json`)
/// that make a custom video show up as an aerial. One stable asset id means a
/// new lock-screen video replaces the previous one. Shapes follow Mural (MIT).
public enum AerialManifestEditor {
    public static let assetID = "5F0A1C2E-7B3D-4E8A-9C1F-0A11F1E00001"
    public static let categoryID = "5F0A1C2E-7B3D-4E8A-9C1F-0A11F1E000C1"
    public static let subcategoryID = "5F0A1C2E-7B3D-4E8A-9C1F-0A11F1E000C2"
    static let categoryName = "RedditWallpaper"

    public static func registering(
        title: String, movieURL: URL, previewURL: URL, in manifest: [String: Any]?
    ) -> [String: Any] {
        var root = manifest ?? ["version": 1, "assets": [Any](), "categories": [Any]()]
        if root["version"] == nil { root["version"] = 1 }

        var categories = root["categories"] as? [[String: Any]] ?? []
        categories.removeAll { $0["id"] as? String == categoryID }
        categories.insert(category(previewURL: previewURL), at: 0)
        root["categories"] = categories

        var assets = root["assets"] as? [[String: Any]] ?? []
        assets.removeAll { $0["id"] as? String == assetID }
        assets.insert(asset(title: title, movieURL: movieURL, previewURL: previewURL), at: 0)
        root["assets"] = assets
        return root
    }

    public static func removingOurEntries(from manifest: [String: Any]) -> [String: Any] {
        var root = manifest
        root["assets"] = (manifest["assets"] as? [[String: Any]] ?? []).filter { $0["id"] as? String != assetID }
        root["categories"] = (manifest["categories"] as? [[String: Any]] ?? [])
            .filter { $0["id"] as? String != categoryID }
        return root
    }

    static func asset(title: String, movieURL: URL, previewURL: URL) -> [String: Any] {
        [
            "id": assetID,
            "url-4K-SDR-240FPS": movieURL.absoluteString,
            "previewImage": previewURL.absoluteString,
            "accessibilityLabel": title,
            "localizedNameKey": title,
            "categories": [categoryID],
            "subcategories": [subcategoryID],
            "preferredOrder": 0,
            "includeInShuffle": false,
            "showInTopLevel": true,
            "pointsOfInterest": [String: Any](),
            "shotID": title,
        ]
    }

    static func category(previewURL: URL) -> [String: Any] {
        [
            "id": categoryID,
            "localizedDescriptionKey": "\(categoryName)Description",
            "localizedNameKey": categoryName,
            "preferredOrder": 0,
            "previewImage": previewURL.absoluteString,
            "representativeAssetID": assetID,
            "subcategories": [subcategory(previewURL: previewURL)],
        ]
    }

    static func subcategory(previewURL: URL) -> [String: Any] {
        [
            "id": subcategoryID,
            "localizedDescriptionKey": "\(categoryName)SubDescription",
            "localizedNameKey": "\(categoryName)Sub",
            "preferredOrder": -1,
            "previewImage": previewURL.absoluteString,
            "representativeAssetID": assetID,
        ]
    }
}
