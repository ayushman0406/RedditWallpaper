import AppKit
import SwiftUI
import WallpaperCore

/// The menu bar popover: a fresh mix from your interests, one click to set.
struct MenuBarView: View {
    @Environment(AppModel.self) var model

    var body: some View {
        MenuBarContent(model: model)
    }
}

private struct MenuBarContent: View {
    @Environment(AppRouter.self) var router
    let model: AppModel
    @State var feed: FeedController
    @State var kind: MediaKind
    @State var interestID: String?

    init(model: AppModel) {
        self.model = model
        _feed = State(initialValue: FeedController(model: model))
        _kind = State(initialValue: model.settings.kindPreference == .live ? .video : .photo)
        _interestID = State(initialValue: nil)
    }

    private var collection: LibraryCollection {
        if let interestID, let interest = model.settings.selectedInterests.first(where: { $0.id == interestID }) {
            return .interest(interest)
        }
        return .forYou
    }

    private struct ReloadKey: Hashable {
        var kind: MediaKind
        var collection: LibraryCollection
        var interests: [String]
        var sources: Set<SourceID>
        var hasKey: Bool
    }

    private var reloadKey: ReloadKey {
        ReloadKey(
            kind: kind, collection: collection, interests: model.settings.selectedInterestIDs,
            sources: model.settings.enabledSources, hasKey: model.hasPexelsKey)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            controls
            Divider()
            content
            Divider()
            footer
        }
        .frame(width: 360, height: 600)
        .task(id: reloadKey) {
            await feed.load(collection: collection, kind: kind, sort: .random)
        }
    }

    // MARK: - Sections

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Wallpapers").font(.headline)
                Text(statusLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            if model.settings.activeLiveWallpaper != nil {
                Button {
                    model.toggleLivePause()
                } label: {
                    Image(systemName: model.isLivePlaying ? "pause.fill" : "play.fill")
                }
                .help(model.isLivePlaying ? "Pause the live wallpaper" : "Play the live wallpaper")
            }
            Button {
                Task { await model.applyRandom(kind: kind) }
            } label: {
                Image(systemName: "shuffle")
            }
            .help("Set a random wallpaper from your interests")
            .disabled(model.busyID != nil)
            Button {
                Task { await feed.reload() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help("Load a fresh batch")
            .disabled(feed.isLoading)
        }
        .buttonStyle(.borderless)
        .font(.system(size: 13, weight: .semibold))
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var statusLine: String {
        if let active = model.activeWallpaper {
            return active.kind == .video ? "Playing \(active.title)" : "On your desktop: \(active.title)"
        }
        let count = model.settings.selectedInterests.count
        return count == 0 ? "Popular right now" : "From your \(count) interest\(count == 1 ? "" : "s")"
    }

    private var controls: some View {
        VStack(spacing: 8) {
            Picker("Type", selection: $kind) {
                Text("Photos").tag(MediaKind.photo)
                Text("Live").tag(MediaKind.video)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 14)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    InterestChip(title: "For You", symbol: "sparkles", tint: .accentColor, isSelected: interestID == nil) {
                        interestID = nil
                    }
                    ForEach(model.settings.selectedInterests) { interest in
                        InterestChip(
                            title: interest.name, symbol: interest.symbol, tint: interest.tint,
                            isSelected: interestID == interest.id
                        ) {
                            interestID = interest.id
                        }
                    }
                }
                .padding(.horizontal, 14)
            }
        }
        .padding(.bottom, 10)
    }

    @ViewBuilder private var content: some View {
        if kind == .video, !model.hasPexelsKey, model.library.localVideos.isEmpty {
            LiveSetupPrompt()
        } else if feed.items.isEmpty {
            if feed.isLoading || !feed.hasLoaded {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                EmptyFeedMessage(errors: feed.errors) {
                    Task { await feed.reload() }
                }
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 10) {
                    if let message = model.lastError {
                        NoticeBanner(message: message, dismiss: { model.lastError = nil })
                    }
                    ForEach(feed.items.prefix(30)) { wallpaper in
                        PopoverCard(wallpaper: wallpaper) { feed.remove(id: wallpaper.id) }
                    }
                }
                .padding(12)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Button {
                router.openLibrary(collection)
            } label: {
                Label("Open Library", systemImage: "square.grid.2x2")
            }
            .buttonStyle(.borderedProminent)
            Button("Settings") { router.openSettings(nil) }
            Spacer()
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
        }
        .controlSize(.regular)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

/// One wallpaper in the popover: the image is the card.
private struct PopoverCard: View {
    @Environment(AppModel.self) var model
    let wallpaper: Wallpaper
    let onHide: () -> Void
    @State var isHovering = false

    var body: some View {
        Color.clear
            .frame(height: 180)
            .overlay { ThumbnailView(url: wallpaper.thumbnailURL) }
            .overlay {
                LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .center, endPoint: .bottom)
            }
            .overlay(alignment: .bottomLeading) {
                HStack(alignment: .bottom, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(wallpaper.title)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        WallpaperBadges(wallpaper: wallpaper)
                    }
                    Spacer(minLength: 4)
                    SetWallpaperButton(wallpaper: wallpaper)
                }
                .padding(10)
            }
            .overlay(alignment: .topTrailing) {
                if isHovering || model.isFavorite(wallpaper) {
                    FavoriteButton(wallpaper: wallpaper).padding(8)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .onHover { isHovering = $0 }
            .animation(.easeOut(duration: 0.12), value: isHovering)
            .contextMenu { WallpaperMenuItems(wallpaper: wallpaper, onHide: onHide) }
    }
}

/// Shown on the Live tab until there is something to play.
private struct LiveSetupPrompt: View {
    @Environment(AppRouter.self) var router

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "play.rectangle.on.rectangle")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(.secondary)
            Text("Live wallpapers need a free Pexels key")
                .font(.headline)
            Text("Pexels has thousands of free videos of cars, surfing, football and more. Paste a key once and they show up here. You can also import your own videos.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack {
                Button("Add Pexels Key") { router.openSettings(.sources) }
                    .buttonStyle(.borderedProminent)
                Button("Import a Video") { router.openLibrary(.myVideos) }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Shown when a load finished with nothing to show.
struct EmptyFeedMessage: View {
    let errors: [SourceError]
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: errors.isEmpty ? "photo.on.rectangle" : "wifi.exclamationmark")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(.secondary)
            Text(errors.isEmpty ? "Nothing here yet" : "Couldn't load wallpapers")
                .font(.headline)
            Text(errors.isEmpty
                 ? "Try another interest, or switch between Photos and Live."
                 : errors.map(\.message).joined(separator: "\n"))
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Try Again", action: retry)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
