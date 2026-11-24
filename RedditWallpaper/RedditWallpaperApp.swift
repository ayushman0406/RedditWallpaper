import AppKit
import SwiftUI

@main
struct RedditWallpaperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // The real windows are managed by WindowCoordinator; this scene only
        // supplies menu commands while one of them is open.
        Settings {
            EmptyView()
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") { appDelegate.coordinator.showSettings() }
                    .keyboardShortcut(",", modifiers: .command)
            }
            CommandGroup(replacing: .newItem) {
                Button("Wallpaper Library") { appDelegate.coordinator.showLibrary() }
                    .keyboardShortcut("l", modifiers: [.command, .shift])
            }
        }
    }
}
