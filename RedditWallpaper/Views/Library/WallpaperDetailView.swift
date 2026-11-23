import AppKit
import AVFoundation
import AVKit
import SwiftUI
import WallpaperCore

/// A large preview with credits and every action for one wallpaper.
struct WallpaperDetailView: View {
    @Environment(AppModel.self) var model
    @Environment(\.dismiss) var dismiss
    let wallpaper: Wallpaper
    var onHide: (Wallpaper) -> Void = { _ in }

    var body: some View {
        VStack(spacing: 0) {
            preview
                .frame(maxWidth: .infinity)
                .frame(height: 430)
                .clipped()
                .overlay(alignment: .topTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .frame(width: 28, height: 28)
                            .background(.regularMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.cancelAction)
                    .accessibilityLabel("Close")
                    .padding(12)
                }

            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(wallpaper.title)
                        .font(.title2.weight(.semibold))
                        .lineLimit(2)
                    credit
                    facts
                    if !interests.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(interests) { interest in
                                Label(interest.name, systemImage: SymbolImage.resolve(interest.symbol, fallback: "star.fill"))
                                    .font(.caption.weight(.medium))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .foregroundStyle(interest.tint)
                                    .background(interest.tint.opacity(0.12), in: Capsule())
                            }
                        }
                    }
                }
                Spacer(minLength: 12)
                VStack(alignment: .trailing, spacing: 10) {
                    SetWallpaperButton(wallpaper: wallpaper, large: true)
                    Text(wallpaper.kind == .photo
                         ? "Shows on your desktop and lock screen."
                         : "Plays behind your desktop icons on every screen.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        Button {
                            model.toggleFavorite(wallpaper)
                        } label: {
                            Label(
                                model.isFavorite(wallpaper) ? "Favorited" : "Favorite",
                                systemImage: model.isFavorite(wallpaper) ? "heart.fill" : "heart")
                        }
                        if let page = wallpaper.pageURL {
                            Button {
                                NSWorkspace.shared.open(page)
                            } label: {
                                Label("Source", systemImage: "safari")
                            }
                        }
                        if wallpaper.source != .local {
                            Button {
                                model.hide(wallpaper)
                                onHide(wallpaper)
                                dismiss()
                            } label: {
                                Label("Hide", systemImage: "eye.slash")
                            }
                            .help("Never show this wallpaper again")
                        }
                    }
                    .controlSize(.small)
                    if wallpaper.kind == .video {
                        LockScreenVideoButton(wallpaper: wallpaper)
                    }
                }
            }
            .padding(20)

            if let message = model.lastError {
                NoticeBanner(message: message, dismiss: { model.lastError = nil })
                    .padding([.horizontal, .bottom], 20)
            }
        }
        .frame(width: 780)
    }

    private var interests: [Interest] {
        model.settings.selectedInterests.filter { wallpaper.interestIDs.contains($0.id) }
    }

    @ViewBuilder private var preview: some View {
        if wallpaper.kind == .video {
            VideoPreview(url: wallpaper.mediaURL)
        } else {
            ThumbnailView(url: wallpaper.mediaURL, placeholder: wallpaper.thumbnailURL)
        }
    }

    @ViewBuilder private var credit: some View {
        let author = wallpaper.author.map { "by \($0) " } ?? ""
        if let page = wallpaper.pageURL {
            Link("\(author)on \(wallpaper.source.displayName)", destination: page)
                .font(.callout)
        } else {
            Text("\(author)from \(wallpaper.source.displayName)")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var facts: some View {
        HStack(spacing: 12) {
            if let label = wallpaper.resolutionLabel {
                Label(label, systemImage: "aspectratio")
            }
            if let badge = wallpaper.qualityBadge {
                Text(badge)
            }
            if let duration = wallpaper.duration, duration > 0 {
                Label("\(Int(duration.rounded())) s loop", systemImage: "repeat")
            }
            if let score = wallpaper.score, score > 0 {
                Label("\(score)", systemImage: wallpaper.source == .reddit ? "arrow.up" : "heart")
            }
        }
        .font(.callout)
        .foregroundStyle(.secondary)
    }
}

/// A muted, looping preview of a video wallpaper.
private struct VideoPreview: View {
    let url: URL
    @State var looper = PreviewLooper()

    var body: some View {
        VideoPlayer(player: looper.player)
            .onAppear { looper.start(url) }
            .onDisappear { looper.stop() }
    }
}

private final class PreviewLooper {
    let player = AVQueuePlayer()
    private var looper: AVPlayerLooper?

    func start(_ url: URL) {
        player.isMuted = true
        looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
        player.play()
    }

    func stop() {
        player.pause()
        looper?.disableLooping()
        looper = nil
        player.removeAllItems()
    }
}
