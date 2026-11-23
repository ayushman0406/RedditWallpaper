import AppKit
import Foundation
import WallpaperCore

/// Changes the wallpaper on a schedule. Checks once a minute and right after
/// the Mac wakes, so a missed slot (lid closed) is caught up immediately.
final class AutoChanger {
    private let fire: () async -> Void
    private var timer: Timer?
    private var wakeObserver: NSObjectProtocol?
    private var interval: AutoChangeInterval = .off
    private var lastChange: Date?
    private var isFiring = false

    init(fire: @escaping () async -> Void) {
        self.fire = fire
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.check() }
        }
    }

    func update(interval: AutoChangeInterval, lastChange: Date?) {
        self.interval = interval
        self.lastChange = lastChange
        timer?.invalidate()
        timer = nil
        guard interval != .off else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.check() }
        }
        check()
    }

    private func check() {
        guard !isFiring, interval.isDue(lastChange: lastChange, now: Date()) else { return }
        isFiring = true
        // Count the attempt even if it fails, so a dead network retries at the
        // next slot instead of every minute.
        lastChange = Date()
        Task { @MainActor in
            await fire()
            isFiring = false
        }
    }
}
