import Foundation
import AppKit

class DesktopManager {
    static func setWallpaper(url: URL) {
        let workspace = NSWorkspace.shared
        let screens = NSScreen.screens
        
        for screen in screens {
            do {
                try workspace.setDesktopImageURL(url, for: screen, options: [:])
            } catch {
                print("Failed to set wallpaper for screen \(screen): \(error)")
            }
        }
    }
}
