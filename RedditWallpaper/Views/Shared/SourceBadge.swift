import AppKit
import SwiftUI
import WallpaperCore

/// A small label on top of imagery.
struct MediaBadge: View {
    let text: String
    var symbol: String? = nil

    var body: some View {
        HStack(spacing: 3) {
            if let symbol { Image(systemName: symbol) }
            Text(text)
        }
        .font(.caption2.weight(.semibold))
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(.black.opacity(0.4), in: Capsule())
        .foregroundStyle(.white)
    }
}

/// Source, Live and quality badges for a wallpaper.
struct WallpaperBadges: View {
    let wallpaper: Wallpaper

    var body: some View {
        HStack(spacing: 5) {
            MediaBadge(text: wallpaper.source.displayName)
            if wallpaper.kind == .video { MediaBadge(text: "Live", symbol: "play.fill") }
            if let quality = wallpaper.qualityBadge { MediaBadge(text: quality) }
        }
    }
}

struct FavoriteButton: View {
    @Environment(AppModel.self) var model
    let wallpaper: Wallpaper

    var body: some View {
        let isFavorite = model.isFavorite(wallpaper)
        Button {
            model.toggleFavorite(wallpaper)
        } label: {
            Image(systemName: isFavorite ? "heart.fill" : "heart")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isFavorite ? Color.pink : Color.white)
                .frame(width: 28, height: 28)
                .background(.black.opacity(0.4), in: Circle())
        }
        .buttonStyle(.plain)
        .help(isFavorite ? "Remove from Favorites" : "Add to Favorites")
        .accessibilityLabel(isFavorite ? "Remove from Favorites" : "Add to Favorites")
    }
}

/// "Set" while idle, progress while downloading, a check once it's on the desktop.
struct SetWallpaperButton: View {
    @Environment(AppModel.self) var model
    let wallpaper: Wallpaper
    var large = false

    var body: some View {
        if model.isBusy(wallpaper) {
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                if let progress = model.downloadProgress, progress > 0, progress < 1 {
                    Text("\(Int(progress * 100))%").monospacedDigit()
                } else {
                    Text("Setting…")
                }
            }
            .font(large ? .body : .caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, large ? 7 : 4)
            .background(.regularMaterial, in: Capsule())
        } else if model.isActive(wallpaper) {
            Label(wallpaper.kind == .video ? "Playing" : "On Desktop", systemImage: "checkmark.circle.fill")
                .font(large ? .body.weight(.medium) : .caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, large ? 7 : 4)
                .background(.regularMaterial, in: Capsule())
        } else {
            Button {
                Task { await model.apply(wallpaper) }
            } label: {
                Label(
                    large ? (wallpaper.kind == .video ? "Set as Live Wallpaper" : "Set as Wallpaper")
                        : (wallpaper.kind == .video ? "Set Live" : "Set"),
                    systemImage: wallpaper.kind == .video ? "play.fill" : "photo")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(large ? .large : .small)
            .disabled(model.busyID != nil)
        }
    }
}

/// Context-menu actions shared by cards in the popover and the Library.
struct WallpaperMenuItems: View {
    @Environment(AppModel.self) var model
    let wallpaper: Wallpaper
    var onHide: (() -> Void)? = nil

    var body: some View {
        Button(wallpaper.kind == .video ? "Set as Live Wallpaper" : "Set as Wallpaper") {
            Task { await model.apply(wallpaper) }
        }
        Button(model.isFavorite(wallpaper) ? "Remove from Favorites" : "Add to Favorites") {
            model.toggleFavorite(wallpaper)
        }
        if let page = wallpaper.pageURL {
            Button("Open Source Page") { NSWorkspace.shared.open(page) }
        }
        Divider()
        if wallpaper.source == .local {
            Button("Delete Video", role: .destructive) { model.removeLocalVideo(wallpaper) }
        } else {
            Button("Hide This Wallpaper") {
                model.hide(wallpaper)
                onHide?()
            }
        }
    }
}

/// A dismissible notice with an optional action.
struct NoticeBanner: View {
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    var dismiss: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            Text(message)
                .font(.callout)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            if let actionTitle, let action {
                Button(actionTitle, action: action).controlSize(.small)
            }
            if let dismiss {
                Button(action: dismiss) { Image(systemName: "xmark") }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Dismiss")
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.orange.opacity(0.12)))
    }
}

/// Explains which sources failed in the last load, with a shortcut to the
/// setting that fixes a rejected key.
struct SourceErrorsBanner: View {
    @Environment(AppRouter.self) var router
    let errors: [SourceError]

    var body: some View {
        let keyProblem = errors.contains { error in
            if case let .badStatus(source, status, _) = error { return source == .pexels && (status == 401 || status == 403) }
            return false
        }
        NoticeBanner(
            message: errors.map(\.message).joined(separator: "\n"),
            actionTitle: keyProblem ? "Open Settings" : nil,
            action: keyProblem ? { router.openSettings(.sources) } : nil)
    }
}
