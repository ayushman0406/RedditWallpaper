import AppKit
import Foundation
import Observation
import WallpaperCore

/// The app's state and actions, shared by the popover and every window.
@Observable
final class AppModel {
    var settings: AppSettings {
        didSet { settingsChanged(from: oldValue) }
    }
    private(set) var library: LibraryState {
        didSet { saveLibrary() }
    }
    private(set) var pexelsKey: String? = nil
    /// What is on the desktop right now, if this app set it.
    private(set) var activeWallpaper: Wallpaper? = nil
    /// The wallpaper being downloaded/applied, for progress UI.
    private(set) var busyID: String? = nil
    private(set) var downloadProgress: Double? = nil
    var lastError: String? = nil
    private(set) var isLivePlaying = false
    private(set) var isInstallingLockScreen = false
    private(set) var lockScreenMessage: String? = nil

    @ObservationIgnored let video: VideoWallpaperController
    @ObservationIgnored let lockScreen: LockScreenService
    @ObservationIgnored private let applier: WallpaperApplier
    @ObservationIgnored private let settingsStore: SettingsStore
    @ObservationIgnored private let libraryStore: LibraryFileStore
    @ObservationIgnored private let photoCache: DownloadCache
    @ObservationIgnored private let videoCache: DownloadCache
    @ObservationIgnored let localVideoDirectory: URL
    @ObservationIgnored private let client = URLSessionHTTPClient()
    @ObservationIgnored private var autoChanger: AutoChanger? = nil

    init() {
        let root = DownloadCache.appSupportRoot
        let settingsStore = SettingsStore()
        let libraryStore = LibraryFileStore(fileURL: root.appendingPathComponent("library.json"))
        let applier = WallpaperApplier()
        self.settingsStore = settingsStore
        self.libraryStore = libraryStore
        self.applier = applier
        settings = settingsStore.load()
        library = libraryStore.load()
        photoCache = DownloadCache(directory: root.appendingPathComponent("Cache/Photos", isDirectory: true))
        videoCache = DownloadCache(directory: root.appendingPathComponent("Cache/Videos", isDirectory: true))
        localVideoDirectory = root.appendingPathComponent("My Videos", isDirectory: true)
        video = VideoWallpaperController(applier: applier)
        lockScreen = LockScreenService(appSupportRoot: root)
        try? FileManager.default.createDirectory(at: localVideoDirectory, withIntermediateDirectories: true)
        video.preferences = playbackPreferences
        video.onStateChange = { [weak self] in
            self?.isLivePlaying = self?.video.isPlaying ?? false
        }
    }

    /// Called once the app has finished launching.
    func start() {
        pexelsKey = KeychainStore.read(KeychainStore.pexelsAccount)
        restoreLiveWallpaper()
        autoChanger = AutoChanger { [weak self] in
            await self?.autoChange()
        }
        autoChanger?.update(interval: settings.autoChange, lastChange: settings.lastAutoChange)
        if settings.lockScreenVideoEnabled {
            lockScreen.startMonitoring()
        }
    }

    // MARK: - Sources

    var hasPexelsKey: Bool { !(pexelsKey ?? "").isEmpty }

    func setPexelsKey(_ key: String?) {
        let trimmed = key?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        KeychainStore.write(trimmed, account: KeychainStore.pexelsAccount)
        pexelsKey = trimmed.isEmpty ? nil : trimmed
    }

    func feedService() -> FeedService {
        FeedService(
            sources: [
                RedditSource(),
                WallhavenSource(),
                PexelsSource(apiKey: pexelsKey, maxVideoWidth: settings.videoQuality.rawValue),
                BingDailySource(),
            ],
            client: client)
    }

    func localItems(for collection: LibraryCollection) -> [Wallpaper] {
        switch collection {
        case .favorites: library.favorites
        case .history: library.history
        case .myVideos: library.localVideos
        default: []
        }
    }

    // MARK: - Applying

    func isBusy(_ wallpaper: Wallpaper) -> Bool { busyID == wallpaper.id }
    func isActive(_ wallpaper: Wallpaper) -> Bool { activeWallpaper?.id == wallpaper.id }

    func apply(_ wallpaper: Wallpaper) async {
        guard busyID == nil else { return }
        busyID = wallpaper.id
        downloadProgress = nil
        lastError = nil
        defer {
            busyID = nil
            downloadProgress = nil
        }
        do {
            switch wallpaper.kind {
            case .photo:
                let file = try await photoCache.localFile(for: wallpaper) { [weak self] fraction in
                    self?.downloadProgress = fraction
                }
                video.stop()
                settings.activeLiveWallpaper = nil
                try applier.setStill(fileURL: file)
                photoCache.prune(keeping: [file], maxBytes: 600 * 1024 * 1024)
            case .video:
                let file = try await videoCache.localFile(for: wallpaper) { [weak self] fraction in
                    self?.downloadProgress = fraction
                }
                video.play(fileURL: file, wallpaper: wallpaper)
                settings.activeLiveWallpaper = wallpaper
                videoCache.prune(keeping: [file], maxBytes: 3 * 1024 * 1024 * 1024)
                await afterLiveWallpaperApplied(file: file, wallpaper: wallpaper)
            }
            activeWallpaper = wallpaper
            library.recordApplied(wallpaper)
        } catch {
            lastError = "Couldn't set “\(wallpaper.title)”: \(error.localizedDescription)"
        }
    }

    /// Picks something new from the user's interests and applies it.
    func applyRandom(kind: MediaKind) async {
        if kind == .video, !hasPexelsKey, library.localVideos.isEmpty {
            lastError = "Add a free Pexels key in Settings → Sources to get live wallpapers."
            return
        }
        let interests = settings.selectedInterests
        var request = FeedRequest(
            scopes: interests.isEmpty ? [.general] : interests.map { .interest($0) },
            kind: kind, sort: .random, page: Int.random(in: 1...3))
        request.enabledSources = settings.enabledSources
        request.excludedIDs = library.blockedIDs.union(library.history.prefix(30).map(\.id))
        request.seed = String(UUID().uuidString.prefix(8))
        let page = await feedService().load(request)
        var candidates = page.items
        if kind == .video { candidates += library.localVideos }
        guard let pick = candidates.randomElement() else {
            lastError = page.errors.first?.message ?? "Nothing new found for your interests right now."
            return
        }
        await apply(pick)
    }

    func stopLiveWallpaper() {
        video.stop()
        settings.activeLiveWallpaper = nil
        if activeWallpaper?.kind == .video { activeWallpaper = nil }
    }

    func toggleLivePause() {
        video.setUserPaused(!video.isUserPaused)
    }

    /// When lock-screen video is on, a new live wallpaper also goes to the
    /// lock screen. Runs in the background: converting a 4K video takes a while.
    func afterLiveWallpaperApplied(file: URL, wallpaper: Wallpaper) async {
        guard settings.lockScreenVideoEnabled else { return }
        Task { await installLockScreenVideo(file: file, title: wallpaper.title) }
    }

    // MARK: - Lock screen (experimental)

    func setLockScreenVideoEnabled(_ enabled: Bool) async {
        if enabled {
            settings.lockScreenVideoEnabled = true
            lockScreen.startMonitoring()
            if let live = settings.activeLiveWallpaper, let file = cachedVideoFile(for: live) {
                await installLockScreenVideo(file: file, title: live.title)
            } else {
                lockScreenMessage = "On. The next live wallpaper you set also plays on the lock screen."
            }
        } else {
            settings.lockScreenVideoEnabled = false
            restoreLockScreen()
        }
    }

    /// Puts one specific live wallpaper on the lock screen.
    func useOnLockScreen(_ wallpaper: Wallpaper) async {
        do {
            let file = try await videoCache.localFile(for: wallpaper)
            settings.lockScreenVideoEnabled = true
            await installLockScreenVideo(file: file, title: wallpaper.title)
        } catch {
            lockScreenMessage = "Couldn't download “\(wallpaper.title)”: \(error.localizedDescription)"
            lastError = lockScreenMessage
        }
    }

    func restoreLockScreen() {
        do {
            try lockScreen.restore()
            lockScreenMessage = "Restored the macOS lock screen and screen saver."
        } catch {
            lockScreenMessage = "Couldn't restore: \(error.localizedDescription)"
        }
    }

    private func installLockScreenVideo(file: URL, title: String) async {
        guard !isInstallingLockScreen else { return }
        isInstallingLockScreen = true
        defer { isInstallingLockScreen = false }
        do {
            try await lockScreen.install(videoFile: file, title: title)
            lockScreenMessage = "“\(title)” now plays on the lock screen once the screen saver starts."
        } catch {
            lockScreenMessage = error.localizedDescription
            lastError = "Lock screen: \(error.localizedDescription)"
        }
    }

    private func cachedVideoFile(for wallpaper: Wallpaper) -> URL? {
        let file = wallpaper.mediaURL.isFileURL ? wallpaper.mediaURL : videoCache.fileURL(for: wallpaper)
        return FileManager.default.fileExists(atPath: file.path) ? file : nil
    }

    // MARK: - Library

    func isFavorite(_ wallpaper: Wallpaper) -> Bool { library.isFavorite(wallpaper.id) }

    func toggleFavorite(_ wallpaper: Wallpaper) {
        library.toggleFavorite(wallpaper)
    }

    /// Never show this wallpaper again in feeds.
    func hide(_ wallpaper: Wallpaper) {
        library.block(wallpaper.id)
    }

    func removeLocalVideo(_ wallpaper: Wallpaper) {
        guard wallpaper.source == .local else { return }
        if activeWallpaper?.id == wallpaper.id { stopLiveWallpaper() }
        try? FileManager.default.removeItem(at: wallpaper.mediaURL)
        try? FileManager.default.removeItem(at: wallpaper.thumbnailURL)
        library.removeLocalVideo(id: wallpaper.id)
    }

    /// Copies a video file into the app so it can be a live wallpaper.
    func importVideo(from url: URL) async {
        let id = UUID().uuidString
        let ext = url.pathExtension.isEmpty ? "mp4" : url.pathExtension.lowercased()
        let destination = localVideoDirectory.appendingPathComponent(id).appendingPathExtension(ext)
        let poster = localVideoDirectory.appendingPathComponent(id).appendingPathExtension("jpg")
        do {
            try FileManager.default.copyItem(at: url, to: destination)
            try await VideoFrames.writeFrame(of: destination, to: poster)
            let info = await VideoFrames.info(of: destination)
            let wallpaper = Wallpaper(
                id: "local:\(id)", source: .local, kind: .video,
                title: url.deletingPathExtension().lastPathComponent,
                thumbnailURL: poster, mediaURL: destination,
                width: info.width, height: info.height, duration: info.duration)
            library.addLocalVideo(wallpaper)
        } catch {
            try? FileManager.default.removeItem(at: destination)
            try? FileManager.default.removeItem(at: poster)
            lastError = "Couldn't import \(url.lastPathComponent): \(error.localizedDescription)"
        }
    }

    // MARK: - Onboarding

    func completeOnboarding() {
        settings.hasCompletedOnboarding = true
    }

    // MARK: - Private

    private var playbackPreferences: PlaybackPreferences {
        PlaybackPreferences(
            pauseOnBattery: settings.pauseVideoOnBattery,
            pauseWhenCovered: settings.pauseVideoWhenCovered)
    }

    private func settingsChanged(from old: AppSettings) {
        settingsStore.save(settings)
        if old.pauseVideoOnBattery != settings.pauseVideoOnBattery
            || old.pauseVideoWhenCovered != settings.pauseVideoWhenCovered {
            video.preferences = playbackPreferences
        }
        if old.autoChange != settings.autoChange || old.lastAutoChange != settings.lastAutoChange {
            autoChanger?.update(interval: settings.autoChange, lastChange: settings.lastAutoChange)
        }
    }

    private func saveLibrary() {
        do {
            try libraryStore.save(library)
        } catch {
            lastError = "Couldn't save your library: \(error.localizedDescription)"
        }
    }

    private func restoreLiveWallpaper() {
        guard let live = settings.activeLiveWallpaper else { return }
        guard let file = cachedVideoFile(for: live) else {
            settings.activeLiveWallpaper = nil
            return
        }
        video.play(fileURL: file, wallpaper: live)
        activeWallpaper = live
    }

    private func autoChange() async {
        await applyRandom(kind: settings.autoChangeKind)
        settings.lastAutoChange = Date()
    }
}
