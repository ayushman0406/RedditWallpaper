import AppKit
import SwiftUI
import WallpaperCore

struct SettingsView: View {
    @Environment(AppRouter.self) var router

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.settingsTab) {
            InterestsSettings()
                .tabItem { Label(SettingsTab.interests.title, systemImage: SettingsTab.interests.symbol) }
                .tag(SettingsTab.interests)
            SourcesSettings()
                .tabItem { Label(SettingsTab.sources.title, systemImage: SettingsTab.sources.symbol) }
                .tag(SettingsTab.sources)
            AutoChangeSettings()
                .tabItem { Label(SettingsTab.autoChange.title, systemImage: SettingsTab.autoChange.symbol) }
                .tag(SettingsTab.autoChange)
            LiveSettings()
                .tabItem { Label(SettingsTab.live.title, systemImage: SettingsTab.live.symbol) }
                .tag(SettingsTab.live)
            LockScreenSettings()
                .tabItem { Label(SettingsTab.lockScreen.title, systemImage: SettingsTab.lockScreen.symbol) }
                .tag(SettingsTab.lockScreen)
            GeneralSettings()
                .tabItem { Label(SettingsTab.general.title, systemImage: SettingsTab.general.symbol) }
                .tag(SettingsTab.general)
        }
        .padding(20)
        .frame(minWidth: 600, minHeight: 480)
    }
}

// MARK: - Interests

private struct InterestsSettings: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pick what you want to see. The menu bar, the Library and auto-change all use these.")
                .foregroundStyle(.secondary)
            ScrollView { InterestPicker().padding(.vertical, 2) }
        }
    }
}

// MARK: - Sources

private struct SourcesSettings: View {
    @Environment(AppModel.self) var model
    @State var keyText = ""

    var body: some View {
        Form {
            Section("Where wallpapers come from") {
                sourceToggle(.wallhaven, detail: "Huge library of high-resolution art, anime and photos. No setup.")
                sourceToggle(.reddit, detail: "Popular posts from wallpaper subreddits, through meme-api.com.")
                sourceToggle(.bing, detail: "Bing's photo of the day, in 4K.")
                sourceToggle(.pexels, detail: "Free stock photos and videos. Needs a free API key.")
            }
            Section {
                HStack {
                    TextField("Pexels API key", text: $keyText)
                        .textFieldStyle(.roundedBorder)
                    Button("Save") { model.setPexelsKey(keyText) }
                        .disabled(keyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if model.hasPexelsKey {
                        Button("Remove", role: .destructive) {
                            model.setPexelsKey(nil)
                            keyText = ""
                        }
                    }
                }
                Label(
                    model.hasPexelsKey ? "Key saved in your keychain." : "No key yet. Live wallpapers from Pexels are off.",
                    systemImage: model.hasPexelsKey ? "checkmark.seal.fill" : "key")
                    .foregroundStyle(model.hasPexelsKey ? Color.green : Color.secondary)
                Link("Get a free key at pexels.com/api", destination: URL(string: "https://www.pexels.com/api/")!)
            } header: {
                Text("Pexels")
            } footer: {
                Text("Photos and videos from Pexels are free to use. The app credits the photographer on every wallpaper.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear { keyText = model.pexelsKey ?? "" }
    }

    private func sourceToggle(_ source: SourceID, detail: String) -> some View {
        Toggle(isOn: Binding(
            get: { model.settings.enabledSources.contains(source) },
            set: { isOn in
                if isOn {
                    model.settings.enabledSources.insert(source)
                } else {
                    model.settings.enabledSources.remove(source)
                }
            }
        )) {
            VStack(alignment: .leading, spacing: 2) {
                Text(source.displayName)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Auto-change

private struct AutoChangeSettings: View {
    @Environment(AppModel.self) var model

    var body: some View {
        @Bindable var model = model
        Form {
            Section {
                Picker("Change wallpaper", selection: $model.settings.autoChange) {
                    ForEach(AutoChangeInterval.allCases, id: \.self) { interval in
                        Text(interval.displayName).tag(interval)
                    }
                }
                Picker("Use", selection: $model.settings.autoChangeKind) {
                    Text("Photos").tag(MediaKind.photo)
                    Text("Live wallpapers").tag(MediaKind.video)
                }
                .disabled(model.settings.autoChange == .off)
            } footer: {
                Text("Picks something new from your interests. A change that was due while your Mac slept happens when it wakes.")
                    .foregroundStyle(.secondary)
            }
            Section {
                Button("Change Now") {
                    Task { await model.applyRandom(kind: model.settings.autoChangeKind) }
                }
                .disabled(model.busyID != nil)
                if let last = model.settings.lastAutoChange {
                    Text("Last changed \(last.formatted(.relative(presentation: .named)))")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Live wallpapers

private struct LiveSettings: View {
    @Environment(AppModel.self) var model
    @Environment(AppRouter.self) var router

    var body: some View {
        @Bindable var model = model
        Form {
            Section("Playback") {
                Toggle("Pause on battery power", isOn: $model.settings.pauseVideoOnBattery)
                Toggle("Pause when windows cover the desktop", isOn: $model.settings.pauseVideoWhenCovered)
                Picker("Download quality", selection: $model.settings.videoQuality) {
                    ForEach(VideoQuality.allCases, id: \.self) { quality in
                        Text(quality.displayName).tag(quality)
                    }
                }
            }
            Section {
                if let live = model.settings.activeLiveWallpaper {
                    LabeledContent("Playing", value: live.title)
                    Button("Stop Live Wallpaper") { model.stopLiveWallpaper() }
                } else {
                    Text("No live wallpaper is playing.").foregroundStyle(.secondary)
                }
            } footer: {
                Text("Live wallpapers are muted, never keep your Mac awake, and always pause while the screen is off or locked.")
                    .foregroundStyle(.secondary)
            }
            Section {
                Button("Import Videos…") { router.openLibrary(.myVideos) }
                Link("MotionBGs: car live wallpapers", destination: URL(string: "https://motionbgs.com/tag:car/")!)
                Link("MoeWalls: anime and vehicle loops", destination: URL(string: "https://moewalls.com/category/vehicle/")!)
            } header: {
                Text("Your own videos")
            } footer: {
                Text("Download a loop from one of these sites, then import it in My Videos. Use videos you have the right to use.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - General

private struct GeneralSettings: View {
    @Environment(AppModel.self) var model
    @Environment(AppRouter.self) var router
    @State var launchAtLogin = LaunchAtLogin.isEnabled
    @State var loginError: String?

    var body: some View {
        @Bindable var model = model
        Form {
            Section {
                Toggle("Open at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        do {
                            try LaunchAtLogin.set(enabled)
                            loginError = nil
                        } catch {
                            loginError = "Couldn't change the login item: \(error.localizedDescription)"
                            launchAtLogin = LaunchAtLogin.isEnabled
                        }
                    }
                if let loginError {
                    Text(loginError).foregroundStyle(.red).font(.caption)
                }
                Toggle("Show the Library when the app opens", isOn: $model.settings.showLibraryOnLaunch)
            }
            Section {
                Button("Show Welcome Again") { router.openOnboarding() }
            }
            Section {
                LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–")
                Text("Photos from Wallhaven, Reddit (via meme-api.com), Bing and Pexels belong to their creators. Each wallpaper links to its source.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
