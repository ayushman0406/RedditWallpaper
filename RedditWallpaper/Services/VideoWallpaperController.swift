import AppKit
import AVFoundation
import CoreMedia
import Foundation
import QuartzCore
import WallpaperCore

/// Plays a looping, muted video behind the desktop icons on every screen.
/// One player feeds every screen, so the video is decoded once. Playback
/// follows `PlaybackPolicy`: it pauses when screens sleep or lock, when the
/// user switches away, on battery and when the desktop is covered (both
/// optional), so a live wallpaper costs nothing when nobody can see it.
final class VideoWallpaperController {
    private(set) var current: Wallpaper?
    private(set) var currentFile: URL?
    private(set) var isPlaying = false
    var preferences = PlaybackPreferences() {
        didSet { updatePlayback() }
    }
    var onStateChange: (() -> Void)?

    private let applier: WallpaperApplier
    private let power = PowerSourceMonitor()
    private var player: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    private var windows: [VideoWallpaperWindow] = []
    private var conditions = PlaybackConditions()
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []

    init(applier: WallpaperApplier) {
        self.applier = applier
        conditions.onBattery = power.onBattery
        power.onChange = { [weak self] onBattery in
            self?.conditions.onBattery = onBattery
            self?.updatePlayback()
        }
        power.start()
        installObservers()
    }

    func play(fileURL: URL, wallpaper: Wallpaper) {
        tearDownPlayer()
        let queuePlayer = AVQueuePlayer()
        queuePlayer.isMuted = true
        queuePlayer.preventsDisplaySleepDuringVideoPlayback = false
        looper = AVPlayerLooper(player: queuePlayer, templateItem: AVPlayerItem(url: fileURL))
        player = queuePlayer
        current = wallpaper
        currentFile = fileURL
        conditions.userPaused = false
        rebuildWindows()
        Task { await self.setPosterStill(for: fileURL) }
    }

    func stop() {
        tearDownPlayer()
        closeWindows()
        current = nil
        currentFile = nil
        updatePlayback()
    }

    func setUserPaused(_ paused: Bool) {
        conditions.userPaused = paused
        updatePlayback()
    }

    var isUserPaused: Bool { conditions.userPaused }

    // MARK: - Windows

    private func rebuildWindows() {
        closeWindows()
        guard let player else {
            updatePlayback()
            return
        }
        for screen in NSScreen.screens {
            let window = VideoWallpaperWindow(screen: screen, player: player)
            window.orderFrontRegardless()
            windows.append(window)
        }
        updateVisibility()
    }

    private func closeWindows() {
        for window in windows { window.orderOut(nil) }
        windows.removeAll()
    }

    private func updateVisibility() {
        conditions.desktopVisible = windows.isEmpty || windows.contains { $0.occlusionState.contains(.visible) }
        updatePlayback()
    }

    // MARK: - Playback

    private func tearDownPlayer() {
        player?.pause()
        looper?.disableLooping()
        looper = nil
        player = nil
    }

    private func updatePlayback() {
        let shouldPlay = player != nil && PlaybackPolicy.shouldPlay(conditions, preferences)
        if shouldPlay {
            player?.play()
        } else {
            player?.pause()
        }
        isPlaying = shouldPlay
        onStateChange?()
    }

    private func installObservers() {
        let workspace = NSWorkspace.shared.notificationCenter
        observe(workspace, NSWorkspace.screensDidSleepNotification) { $0.conditions.screensAsleep = true }
        observe(workspace, NSWorkspace.screensDidWakeNotification) { $0.conditions.screensAsleep = false }
        observe(workspace, NSWorkspace.sessionDidResignActiveNotification) { $0.conditions.sessionActive = false }
        observe(workspace, NSWorkspace.sessionDidBecomeActiveNotification) { $0.conditions.sessionActive = true }
        let distributed = DistributedNotificationCenter.default()
        observe(distributed, Notification.Name("com.apple.screenIsLocked")) { $0.conditions.screenLocked = true }
        observe(distributed, Notification.Name("com.apple.screenIsUnlocked")) { $0.conditions.screenLocked = false }
        observe(NotificationCenter.default, NSApplication.didChangeScreenParametersNotification) { controller in
            if controller.player != nil { controller.rebuildWindows() }
        }
        observe(NotificationCenter.default, NSWindow.didChangeOcclusionStateNotification) { $0.updateVisibility() }
    }

    private func observe(
        _ center: NotificationCenter, _ name: Notification.Name,
        _ handler: @escaping (VideoWallpaperController) -> Void
    ) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                handler(self)
                self.updatePlayback()
            }
        }
        observers.append((center, token))
    }

    // MARK: - Poster still

    /// Uses a frame of the video as the desktop picture, so the lock screen,
    /// Mission Control and the moment before the video starts all match it.
    private func setPosterStill(for fileURL: URL) async {
        let posterURL = fileURL.deletingPathExtension().appendingPathExtension("poster.jpg")
        do {
            if !FileManager.default.fileExists(atPath: posterURL.path) {
                try await VideoFrames.writeFrame(of: fileURL, to: posterURL)
            }
            guard currentFile == fileURL else { return }
            try applier.setStill(fileURL: posterURL)
        } catch {
            // The video still plays; only the matching still is missing.
        }
    }
}

/// A borderless, click-through window just above the system wallpaper and
/// below the desktop icons, on every Space.
final class VideoWallpaperWindow: NSWindow {
    init(screen: NSScreen, player: AVPlayer) {
        super.init(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        setFrame(screen.frame, display: false)
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        ignoresMouseEvents = true
        isOpaque = true
        hasShadow = false
        backgroundColor = .black
        isReleasedWhenClosed = false
        animationBehavior = .none

        let view = NSView(frame: NSRect(origin: .zero, size: screen.frame.size))
        view.wantsLayer = true
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.frame = view.bounds
        playerLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        view.layer?.addSublayer(playerLayer)
        contentView = view
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
