import AppKit
import Foundation
import SwiftUI
import WallpaperCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()
    private(set) lazy var coordinator = WindowCoordinator(model: model)
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Read before anything else: the launch event is only current now.
        let launchedAtLogin = LaunchAtLogin.wasLaunchedAtLogin
        NSApp.setActivationPolicy(.accessory)
        model.start()
        setUpStatusItem()

        if !model.settings.hasCompletedOnboarding {
            coordinator.showOnboarding()
        } else if model.settings.showLibraryOnLaunch, !launchedAtLogin {
            coordinator.showLibrary()
        }
    }

    /// Opening the app again (Finder, Spotlight, Launchpad) shows the Library.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if model.settings.hasCompletedOnboarding {
            coordinator.showLibrary()
        } else {
            coordinator.showOnboarding()
        }
        return true
    }

    private func setUpStatusItem() {
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 360, height: 600)
        popover.contentViewController = NSHostingController(
            rootView: MenuBarView().environment(model).environment(coordinator.router))

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "photo.on.rectangle.angled", accessibilityDescription: "Wallpapers")
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
        statusItem = item
        coordinator.router.closePopover = { [weak self] in
            self?.popover.performClose(nil)
        }
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem?.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
