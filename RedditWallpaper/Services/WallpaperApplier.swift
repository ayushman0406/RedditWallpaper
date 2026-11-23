import AppKit
import Foundation

/// Sets a still image as the desktop picture on every screen. macOS shows the
/// desktop picture on the lock screen too, so this covers both.
final class WallpaperApplier {
    func setStill(fileURL: URL) throws {
        let options: [NSWorkspace.DesktopImageOptionKey: Any] = [
            .imageScaling: NSImageScaling.scaleProportionallyUpOrDown.rawValue,
            .allowClipping: true,
        ]
        var lastError: Error?
        for screen in NSScreen.screens {
            do {
                try NSWorkspace.shared.setDesktopImageURL(fileURL, for: screen, options: options)
            } catch {
                lastError = error
            }
        }
        if let lastError { throw lastError }
    }
}
