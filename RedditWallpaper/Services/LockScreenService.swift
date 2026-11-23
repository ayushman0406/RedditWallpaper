import AppKit
import Foundation
import WallpaperCore

/// Experimental: plays a live wallpaper on the lock screen and as the screen
/// saver, using the macOS 26 wallpaper store.
///
/// macOS has no public API for this. The technique follows Mural (MIT,
/// © 2026 Aleksey Tkachenko): register the video as a custom aerial in
/// `~/Library/Application Support/com.apple.wallpaper/aerials/`, point every
/// `Idle` (screen saver) entry in `Store/Index.plist` at it, and restart
/// `WallpaperAgent`. The screen saver is what shows over the lock screen.
/// macOS sometimes reverts the choice, so it is re-applied while enabled.
final class LockScreenService {
    enum LockScreenError: LocalizedError {
        case unavailable
        case systemSettingsOpen
        case unreadableStore

        var errorDescription: String? {
            switch self {
            case .unavailable:
                "This Mac doesn't have the macOS 26 wallpaper settings this feature needs."
            case .systemSettingsOpen:
                "Quit System Settings first. It rewrites the wallpaper settings while it's open."
            case .unreadableStore:
                "macOS's wallpaper settings file couldn't be read, so nothing was changed."
            }
        }
    }

    private let fileManager = FileManager.default
    private let wallpaperRoot: URL
    private let backupDirectory: URL
    private var monitor: Timer?

    init(appSupportRoot: URL) {
        wallpaperRoot = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/com.apple.wallpaper", isDirectory: true)
        backupDirectory = appSupportRoot.appendingPathComponent("LockScreenBackup", isDirectory: true)
    }

    private var storeURL: URL { wallpaperRoot.appendingPathComponent("Store/Index.plist") }
    private var manifestURL: URL { wallpaperRoot.appendingPathComponent("aerials/manifest/entries.json") }
    private var videosDirectory: URL { wallpaperRoot.appendingPathComponent("aerials/videos", isDirectory: true) }
    private var movieURL: URL { videosDirectory.appendingPathComponent("\(AerialManifestEditor.assetID).mov") }
    private var previewURL: URL { videosDirectory.appendingPathComponent("\(AerialManifestEditor.assetID)-preview.png") }
    private var storeBackupURL: URL { backupDirectory.appendingPathComponent("Index.plist") }
    private var manifestBackupURL: URL { backupDirectory.appendingPathComponent("entries.json") }

    var isAvailable: Bool {
        ProcessInfo.processInfo.isOperatingSystemAtLeast(OperatingSystemVersion(majorVersion: 26, minorVersion: 0, patchVersion: 0))
            && fileManager.fileExists(atPath: storeURL.path)
    }

    private var isSystemSettingsOpen: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.systempreferences").isEmpty
    }

    private var desiredConfiguration: Data? {
        try? WallpaperStoreEditor.aerialConfiguration(assetID: AerialManifestEditor.assetID)
    }

    // MARK: - Install / restore

    func install(videoFile: URL, title: String) async throws {
        guard isAvailable else { throw LockScreenError.unavailable }
        guard !isSystemSettingsOpen else { throw LockScreenError.systemSettingsOpen }
        _ = try readStore()
        try backUpIfNeeded()

        try fileManager.createDirectory(at: videosDirectory, withIntermediateDirectories: true)
        let temporary = videosDirectory.appendingPathComponent("\(UUID().uuidString).mov")
        defer { try? fileManager.removeItem(at: temporary) }
        try await VideoTranscoder.makeLockScreenMovie(from: videoFile, to: temporary)
        try? fileManager.removeItem(at: movieURL)
        try fileManager.moveItem(at: temporary, to: movieURL)
        try await VideoFrames.writeFrame(of: movieURL, to: previewURL)

        try register(title: title)
        try writeIdle()
        restartWallpaperAgent()
        startMonitoring()
    }

    /// Puts the screen saver back to what it was before the first install and
    /// removes this app's video from the aerial list.
    func restore() throws {
        stopMonitoring()
        if fileManager.fileExists(atPath: storeURL.path) {
            let original = (try? readPropertyList(at: storeBackupURL)).flatMap(WallpaperStoreEditor.firstIdleChoice(in:))
            let store = try readStore()
            let (updated, _) = WallpaperStoreEditor.settingIdle(
                in: store,
                provider: original?.provider ?? "com.apple.wallpaper.choice.macintosh",
                configuration: original?.configuration ?? Data(),
                now: Date())
            try writePropertyList(updated, to: storeURL)
        }
        if let manifest = try readJSON(at: manifestURL) {
            try writeJSON(AerialManifestEditor.removingOurEntries(from: manifest), to: manifestURL)
        }
        try? fileManager.removeItem(at: movieURL)
        try? fileManager.removeItem(at: previewURL)
        restartWallpaperAgent()
    }

    // MARK: - Keeping it applied

    func startMonitoring() {
        monitor?.invalidate()
        monitor = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.reapplyIfNeeded() }
        }
    }

    func stopMonitoring() {
        monitor?.invalidate()
        monitor = nil
    }

    /// Re-applies the choice when macOS has reverted it.
    func reapplyIfNeeded() {
        guard isAvailable, !isSystemSettingsOpen, fileManager.fileExists(atPath: movieURL.path),
              let configuration = desiredConfiguration,
              let store = try? readStore(),
              !WallpaperStoreEditor.idleMatches(
                in: store, provider: WallpaperStoreEditor.aerialsProvider, configuration: configuration)
        else { return }
        try? register(title: "RedditWallpaper live wallpaper")
        try? writeIdle()
        restartWallpaperAgent()
    }

    func startScreenSaver() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/CoreServices/ScreenSaverEngine.app"))
    }

    // MARK: - Private

    private func register(title: String) throws {
        let manifest = try readJSON(at: manifestURL)
        let updated = AerialManifestEditor.registering(
            title: title, movieURL: movieURL, previewURL: previewURL, in: manifest)
        try fileManager.createDirectory(at: manifestURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try writeJSON(updated, to: manifestURL)
    }

    private func writeIdle() throws {
        guard let configuration = desiredConfiguration else { throw LockScreenError.unreadableStore }
        let (updated, count) = WallpaperStoreEditor.settingIdle(
            in: try readStore(), provider: WallpaperStoreEditor.aerialsProvider,
            configuration: configuration, now: Date())
        guard count > 0 else { throw LockScreenError.unreadableStore }
        try writePropertyList(updated, to: storeURL)
    }

    private func backUpIfNeeded() throws {
        try fileManager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
        if !fileManager.fileExists(atPath: storeBackupURL.path) {
            try fileManager.copyItem(at: storeURL, to: storeBackupURL)
        }
        if !fileManager.fileExists(atPath: manifestBackupURL.path), fileManager.fileExists(atPath: manifestURL.path) {
            try fileManager.copyItem(at: manifestURL, to: manifestBackupURL)
        }
    }

    private func restartWallpaperAgent() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        process.arguments = ["WallpaperAgent"]
        try? process.run()
        process.waitUntilExit()
    }

    private func readStore() throws -> [String: Any] {
        guard let store = try readPropertyList(at: storeURL) else { throw LockScreenError.unreadableStore }
        return store
    }

    private func readPropertyList(at url: URL) throws -> [String: Any]? {
        let data = try Data(contentsOf: url)
        return try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]
    }

    private func writePropertyList(_ value: [String: Any], to url: URL) throws {
        let data = try PropertyListSerialization.data(fromPropertyList: value, format: .binary, options: 0)
        try data.write(to: url, options: .atomic)
    }

    private func readJSON(at url: URL) throws -> [String: Any]? {
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
    }

    private func writeJSON(_ value: [String: Any], to url: URL) throws {
        let data = try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
        try data.write(to: url, options: .atomic)
    }
}
