import Foundation

/// Pure edits of macOS 26's wallpaper store
/// (`~/Library/Application Support/com.apple.wallpaper/Store/Index.plist`).
///
/// The store keeps a `Desktop` and an `Idle` project per scope (SystemDefault,
/// each display, each Space). `Idle` is the screen saver, which is what shows
/// over the lock screen. WallpaperAgent reverts a lone edit, so every `Idle`
/// is written. Technique from Mural (MIT, © 2026 Aleksey Tkachenko).
public enum WallpaperStoreEditor {
    public static let aerialsProvider = "com.apple.wallpaper.choice.aerials"

    /// The nested binary plist that points an aerial choice at an asset.
    public static func aerialConfiguration(assetID: String) throws -> Data {
        try PropertyListSerialization.data(fromPropertyList: ["assetID": assetID], format: .binary, options: 0)
    }

    /// Sets every `Idle` project to one choice; returns the new store and how
    /// many projects were written. `Desktop` projects are left alone.
    public static func settingIdle(
        in store: [String: Any], provider: String, configuration: Data, now: Date
    ) -> (store: [String: Any], count: Int) {
        let options = optionTemplate(for: provider, in: store)
        var count = 0
        func transform(_ node: Any) -> Any {
            if var dictionary = node as? [String: Any] {
                for (key, value) in dictionary {
                    if key == "Idle", var project = value as? [String: Any], project["Content"] != nil {
                        var content = project["Content"] as? [String: Any] ?? [:]
                        let choice: [String: Any] = [
                            "Provider": provider, "Files": [Any](), "Configuration": configuration,
                        ]
                        content["Choices"] = [choice]
                        if let options { content["EncodedOptionValues"] = options }
                        if content["Shuffle"] == nil { content["Shuffle"] = "$null" }
                        project["Content"] = content
                        project["LastSet"] = now
                        project["LastUse"] = now
                        dictionary[key] = project
                        count += 1
                    } else {
                        dictionary[key] = transform(value)
                    }
                }
                return dictionary
            }
            if let array = node as? [Any] {
                return array.map(transform)
            }
            return node
        }
        let updated = transform(store) as? [String: Any] ?? store
        return (updated, count)
    }

    /// True when every `Idle` project already holds this choice.
    public static func idleMatches(in store: [String: Any], provider: String, configuration: Data) -> Bool {
        var found = false
        var matches = true
        walkIdle(in: store) { project in
            found = true
            let choice = firstChoice(of: project)
            if choice?["Provider"] as? String != provider
                || (choice?["Configuration"] as? Data ?? Data()) != configuration {
                matches = false
            }
        }
        return found && matches
    }

    /// True when at least one `Idle` project holds this choice.
    public static func idleContains(in store: [String: Any], provider: String, configuration: Data) -> Bool {
        var found = false
        walkIdle(in: store) { project in
            let choice = firstChoice(of: project)
            if choice?["Provider"] as? String == provider,
               (choice?["Configuration"] as? Data ?? Data()) == configuration {
                found = true
            }
        }
        return found
    }

    /// Undoes this app's screen saver: every `Idle` goes back to `original`,
    /// or to the macOS default when there is no backup. Returns nil when no
    /// `Idle` holds `ours`, so a screen saver the user chose is never touched.
    public static func restoringIdle(
        in store: [String: Any], from ours: (provider: String, configuration: Data),
        to original: (provider: String, configuration: Data)?, now: Date
    ) -> [String: Any]? {
        guard idleContains(in: store, provider: ours.provider, configuration: ours.configuration) else { return nil }
        return settingIdle(
            in: store, provider: original?.provider ?? "com.apple.wallpaper.choice.macintosh",
            configuration: original?.configuration ?? Data(), now: now
        ).store
    }

    /// The current screen-saver choice, preferring the system default scope.
    public static func firstIdleChoice(in store: [String: Any]) -> (provider: String, configuration: Data)? {
        func choice(of project: [String: Any]) -> (provider: String, configuration: Data)? {
            guard let first = firstChoice(of: project), let provider = first["Provider"] as? String else { return nil }
            return (provider, first["Configuration"] as? Data ?? Data())
        }
        if let systemDefault = store["SystemDefault"] as? [String: Any],
           let idle = systemDefault["Idle"] as? [String: Any],
           let result = choice(of: idle) {
            return result
        }
        var result: (provider: String, configuration: Data)?
        walkIdle(in: store) { project in
            if result == nil { result = choice(of: project) }
        }
        return result
    }

    // MARK: - Private

    private static func firstChoice(of project: [String: Any]) -> [String: Any]? {
        ((project["Content"] as? [String: Any])?["Choices"] as? [[String: Any]])?.first
    }

    /// Option values copied from an existing project of the same provider
    /// (or any project), as System Settings writes them.
    private static func optionTemplate(for provider: String, in store: [String: Any]) -> Data? {
        var sameProvider: Data?
        var any: Data?
        walkIdle(in: store) { project in
            guard let content = project["Content"] as? [String: Any],
                  let options = content["EncodedOptionValues"] as? Data, !options.isEmpty else { return }
            if sameProvider == nil, firstChoice(of: project)?["Provider"] as? String == provider {
                sameProvider = options
            }
            if any == nil { any = options }
        }
        return sameProvider ?? any
            ?? (try? PropertyListSerialization.data(
                fromPropertyList: ["values": [String: Any]()], format: .binary, options: 0))
    }

    private static func walkIdle(in node: Any, _ visit: ([String: Any]) -> Void) {
        if let dictionary = node as? [String: Any] {
            for (key, value) in dictionary {
                if key == "Idle", let project = value as? [String: Any], project["Content"] != nil {
                    visit(project)
                } else {
                    walkIdle(in: value, visit)
                }
            }
        } else if let array = node as? [Any] {
            for item in array { walkIdle(in: item, visit) }
        }
    }
}
