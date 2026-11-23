import SwiftUI
import WallpaperCore

struct LockScreenSettings: View {
    @Environment(AppModel.self) var model

    var body: some View {
        Form {
            Section {
                Text("When you set a photo, macOS shows it on your lock screen too. Nothing to turn on.")
            } header: {
                Text("Photos")
            }

            Section {
                Toggle("Play live wallpapers on the lock screen and screen saver", isOn: Binding(
                    get: { model.settings.lockScreenVideoEnabled },
                    set: { enabled in Task { await model.setLockScreenVideoEnabled(enabled) } }))
                    .disabled(!model.lockScreen.isAvailable || model.isInstallingLockScreen)
                if !model.lockScreen.isAvailable {
                    Text("Needs macOS 26 or later.").foregroundStyle(.secondary)
                }
                if model.isInstallingLockScreen {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Preparing the video for the lock screen…")
                    }
                }
                if let message = model.lockScreenMessage {
                    Text(message).font(.callout).foregroundStyle(.secondary)
                }
                HStack {
                    Button("Start Screen Saver Now") { model.lockScreen.startScreenSaver() }
                    Button("Restore macOS Default", role: .destructive) { model.restoreLockScreen() }
                }
            } header: {
                Text("Live wallpapers (experimental)")
            } footer: {
                Text("macOS has no official way to do this. The app adds your video to Apple's aerial wallpaper list and makes it the screen saver, after backing up the original settings. A macOS update can break it; Restore puts everything back. The video appears once the screen saver starts, so set “Require password after screen saver begins” to Immediately in System Settings → Lock Screen. A hot corner set to Start Screen Saver makes it one move.")
                    .foregroundStyle(.secondary)
            }

            Section {
                Text("The screen right after you turn on your Mac (the FileVault unlock screen) loads before your account does, so no app can change it.")
                    .foregroundStyle(.secondary)
            } header: {
                Text("Startup screen")
            }
        }
        .formStyle(.grouped)
    }
}

/// "Use on Lock Screen" in a live wallpaper's detail sheet.
struct LockScreenVideoButton: View {
    @Environment(AppModel.self) var model
    let wallpaper: Wallpaper

    var body: some View {
        if model.lockScreen.isAvailable {
            Button {
                Task { await model.useOnLockScreen(wallpaper) }
            } label: {
                if model.isInstallingLockScreen {
                    Label("Preparing Lock Screen…", systemImage: "hourglass")
                } else {
                    Label("Use on Lock Screen (Experimental)", systemImage: "lock.rectangle")
                }
            }
            .controlSize(.small)
            .disabled(model.isInstallingLockScreen || model.busyID != nil)
            .help("Plays this video as the screen saver, which shows over the lock screen. See Settings → Lock Screen.")
        }
    }
}
