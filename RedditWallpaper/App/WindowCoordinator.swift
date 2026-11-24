import AppKit
import Foundation
import Observation
import SwiftUI
import WallpaperCore

enum SettingsTab: String, CaseIterable, Hashable, Identifiable {
    case interests, sources, autoChange, live, lockScreen, general

    var id: String { rawValue }

    var title: String {
        switch self {
        case .interests: "Interests"
        case .sources: "Sources"
        case .autoChange: "Auto-Change"
        case .live: "Live Wallpapers"
        case .lockScreen: "Lock Screen"
        case .general: "General"
        }
    }

    var symbol: String {
        switch self {
        case .interests: "heart.text.square"
        case .sources: "globe"
        case .autoChange: "timer"
        case .live: "play.rectangle"
        case .lockScreen: "lock.rectangle"
        case .general: "gearshape"
        }
    }
}

/// Navigation state and window actions that SwiftUI views can reach.
@Observable
final class AppRouter {
    var librarySelection: LibraryCollection = .forYou
    var settingsTab: SettingsTab = .interests

    @ObservationIgnored var openLibrary: (LibraryCollection?) -> Void = { _ in }
    @ObservationIgnored var openSettings: (SettingsTab?) -> Void = { _ in }
    @ObservationIgnored var openOnboarding: () -> Void = {}
    @ObservationIgnored var finishOnboarding: () -> Void = {}
    @ObservationIgnored var closePopover: () -> Void = {}
}

/// Owns the Library, Settings and Onboarding windows. The app is a menu bar
/// app (no Dock icon); while one of these windows is open it becomes a normal
/// app so the window can be found with ⌘-Tab, then goes back to the menu bar.
final class WindowCoordinator: NSObject, NSWindowDelegate {
    let router = AppRouter()
    private let model: AppModel
    private var libraryWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private var onboardingWindow: NSWindow?

    init(model: AppModel) {
        self.model = model
        super.init()
        router.openLibrary = { [weak self] collection in self?.showLibrary(collection: collection) }
        router.openSettings = { [weak self] tab in self?.showSettings(tab: tab) }
        router.openOnboarding = { [weak self] in self?.showOnboarding() }
        router.finishOnboarding = { [weak self] in self?.finishOnboarding() }
    }

    func showLibrary(collection: LibraryCollection? = nil) {
        if let collection { router.librarySelection = collection }
        if libraryWindow == nil {
            libraryWindow = makeWindow(
                title: "Wallpaper Library", size: NSSize(width: 1120, height: 740),
                minSize: NSSize(width: 820, height: 520), autosaveName: "LibraryWindow",
                content: LibraryView())
        }
        present(libraryWindow)
    }

    func showSettings(tab: SettingsTab? = nil) {
        if let tab { router.settingsTab = tab }
        if settingsWindow == nil {
            settingsWindow = makeWindow(
                title: "Settings", size: NSSize(width: 680, height: 560),
                minSize: NSSize(width: 600, height: 480), autosaveName: "SettingsWindow",
                content: SettingsView())
        }
        present(settingsWindow)
    }

    func showOnboarding() {
        if onboardingWindow == nil {
            let window = makeWindow(
                title: "Welcome", size: NSSize(width: 760, height: 640),
                minSize: NSSize(width: 700, height: 600), autosaveName: "OnboardingWindow",
                content: OnboardingView())
            window.styleMask.remove(.resizable)
            onboardingWindow = window
        }
        present(onboardingWindow)
    }

    private func finishOnboarding() {
        model.completeOnboarding()
        onboardingWindow?.close()
        showLibrary(collection: .forYou)
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            self?.updateActivationPolicy()
        }
    }

    // MARK: - Private

    private func makeWindow<Content: View>(
        title: String, size: NSSize, minSize: NSSize, autosaveName: String, content: Content
    ) -> NSWindow {
        let hosting = NSHostingController(rootView: content.environment(model).environment(router))
        hosting.sizingOptions = []
        let window = NSWindow(contentViewController: hosting)
        window.title = title
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = false
        window.isReleasedWhenClosed = false
        window.minSize = minSize
        window.setContentSize(size)
        window.delegate = self
        if !window.setFrameUsingName(autosaveName) {
            window.center()
        }
        window.setFrameAutosaveName(autosaveName)
        return window
    }

    private func present(_ window: NSWindow?) {
        guard let window else { return }
        router.closePopover()
        NSApp.setActivationPolicy(.regular)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    private func updateActivationPolicy() {
        let anyVisible = [libraryWindow, settingsWindow, onboardingWindow].contains { $0?.isVisible == true }
        if !anyVisible {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
