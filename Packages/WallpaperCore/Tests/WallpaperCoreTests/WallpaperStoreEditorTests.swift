import Foundation
import Testing
@testable import WallpaperCore

@Suite struct WallpaperStoreEditorTests {
    let provider = WallpaperStoreEditor.aerialsProvider

    func project(provider: String, configuration: Data = Data(), options: Data? = nil) -> [String: Any] {
        var content: [String: Any] = [
            "Choices": [["Provider": provider, "Configuration": configuration, "Files": [Any]()]],
            "Shuffle": "$null",
        ]
        if let options { content["EncodedOptionValues"] = options }
        return ["Content": content, "LastSet": Date(timeIntervalSince1970: 0), "LastUse": Date(timeIntervalSince1970: 0)]
    }

    /// Mirrors the layout of ~/Library/Application Support/com.apple.wallpaper/Store/Index.plist.
    func sampleStore() -> [String: Any] {
        let desktop = project(provider: "com.apple.wallpaper.choice.image", configuration: Data([1, 2, 3]))
        let idleMacintosh = project(provider: "com.apple.wallpaper.choice.macintosh")
        let idleAerial = project(provider: provider, configuration: Data([9]), options: Data([7, 7]))
        return [
            "SystemDefault": ["Type": "individual", "Desktop": desktop, "Idle": idleMacintosh],
            "Displays": ["display-1": ["Type": "individual", "Desktop": desktop, "Idle": idleAerial]],
            "Spaces": ["space-1": ["Default": ["Type": "individual", "Desktop": desktop, "Idle": idleMacintosh],
                                   "Displays": [String: Any]()]],
        ]
    }

    func idleProjects(_ store: [String: Any]) -> [[String: Any]] {
        var result: [[String: Any]] = []
        func walk(_ node: Any) {
            if let dict = node as? [String: Any] {
                for (key, value) in dict {
                    if key == "Idle", let project = value as? [String: Any] { result.append(project) } else { walk(value) }
                }
            } else if let array = node as? [Any] {
                array.forEach(walk)
            }
        }
        walk(store)
        return result
    }

    func firstChoice(_ project: [String: Any]) -> [String: Any]? {
        ((project["Content"] as? [String: Any])?["Choices"] as? [[String: Any]])?.first
    }

    @Test func writesEveryIdleScope() throws {
        let configuration = try WallpaperStoreEditor.aerialConfiguration(assetID: "ASSET")
        let now = Date(timeIntervalSince1970: 100)
        let (store, count) = WallpaperStoreEditor.settingIdle(
            in: sampleStore(), provider: provider, configuration: configuration, now: now)
        #expect(count == 3)
        let idles = idleProjects(store)
        #expect(idles.count == 3)
        for idle in idles {
            #expect(firstChoice(idle)?["Provider"] as? String == provider)
            #expect(firstChoice(idle)?["Configuration"] as? Data == configuration)
            #expect(idle["LastSet"] as? Date == now)
        }
    }

    @Test func leavesDesktopUntouched() throws {
        let configuration = try WallpaperStoreEditor.aerialConfiguration(assetID: "ASSET")
        let (store, _) = WallpaperStoreEditor.settingIdle(
            in: sampleStore(), provider: provider, configuration: configuration, now: Date())
        let display = (store["Displays"] as? [String: Any])?["display-1"] as? [String: Any]
        let desktop = try #require(display?["Desktop"] as? [String: Any])
        #expect(firstChoice(desktop)?["Provider"] as? String == "com.apple.wallpaper.choice.image")
        #expect(firstChoice(desktop)?["Configuration"] as? Data == Data([1, 2, 3]))
    }

    @Test func copiesEncodedOptionValuesFromSameProvider() throws {
        let configuration = try WallpaperStoreEditor.aerialConfiguration(assetID: "ASSET")
        let (store, _) = WallpaperStoreEditor.settingIdle(
            in: sampleStore(), provider: provider, configuration: configuration, now: Date())
        for idle in idleProjects(store) {
            #expect((idle["Content"] as? [String: Any])?["EncodedOptionValues"] as? Data == Data([7, 7]))
        }
    }

    @Test func idleMatchesAfterWrite() throws {
        let configuration = try WallpaperStoreEditor.aerialConfiguration(assetID: "ASSET")
        #expect(!WallpaperStoreEditor.idleMatches(in: sampleStore(), provider: provider, configuration: configuration))
        let (store, _) = WallpaperStoreEditor.settingIdle(
            in: sampleStore(), provider: provider, configuration: configuration, now: Date())
        #expect(WallpaperStoreEditor.idleMatches(in: store, provider: provider, configuration: configuration))
        #expect(!WallpaperStoreEditor.idleMatches(in: [:], provider: provider, configuration: configuration))
    }

    @Test func firstIdleChoiceReadsProviderAndConfiguration() throws {
        let store: [String: Any] = [
            "Displays": ["display-1": ["Idle": project(provider: "com.apple.wallpaper.choice.macintosh", configuration: Data([5]))]],
        ]
        let choice = try #require(WallpaperStoreEditor.firstIdleChoice(in: store))
        #expect(choice.provider == "com.apple.wallpaper.choice.macintosh")
        #expect(choice.configuration == Data([5]))
        #expect(WallpaperStoreEditor.firstIdleChoice(in: [:]) == nil)
    }

    @Test func aerialConfigurationDecodesToAssetID() throws {
        let data = try WallpaperStoreEditor.aerialConfiguration(assetID: "5F0A")
        let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]
        #expect(plist?["assetID"] as? String == "5F0A")
    }
}
