import AppKit
import SwiftUI
import WallpaperCore

/// The Library grid with infinite scroll and empty/error states.
struct WallpaperGrid: View {
    @Environment(AppModel.self) var model
    @Environment(AppRouter.self) var router
    let feed: FeedController
    let kind: MediaKind
    let onOpen: (Wallpaper) -> Void
    let onImport: () -> Void

    private let columns = [GridItem(.adaptive(minimum: 240, maximum: 420), spacing: 14)]

    var body: some View {
        if feed.items.isEmpty {
            emptyState
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let message = model.lastError {
                        NoticeBanner(message: message, dismiss: { model.lastError = nil })
                    }
                    if !feed.errors.isEmpty {
                        SourceErrorsBanner(errors: feed.errors)
                    }
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(feed.items) { wallpaper in
                            WallpaperCard(wallpaper: wallpaper, onOpen: { onOpen(wallpaper) }) {
                                feed.remove(id: wallpaper.id)
                            }
                            .onAppear {
                                if wallpaper.id == feed.items.last?.id {
                                    Task { await feed.loadMore() }
                                }
                            }
                        }
                    }
                    if feed.isLoading {
                        ProgressView().frame(maxWidth: .infinity).padding()
                    }
                }
                .padding(18)
            }
        }
    }

    @ViewBuilder private var emptyState: some View {
        if feed.isLoading || !feed.hasLoaded {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if kind == .video, feed.collection.isRemote, !model.hasPexelsKey {
            EmptyStateView(
                symbol: "play.rectangle.on.rectangle",
                title: "Live wallpapers come from Pexels",
                message: "Add a free Pexels key to see videos for your interests, or import your own videos in My Videos.",
                primary: ("Add Pexels Key", { router.openSettings(.sources) }),
                secondary: ("Open My Videos", { router.librarySelection = .myVideos }))
        } else {
            switch feed.collection {
            case .favorites:
                EmptyStateView(
                    symbol: "heart", title: "No favorites yet",
                    message: "Click the heart on any wallpaper to keep it here.")
            case .history:
                EmptyStateView(
                    symbol: "clock.arrow.circlepath", title: "Nothing set yet",
                    message: "Wallpapers you set appear here, newest first.")
            case .myVideos:
                EmptyStateView(
                    symbol: "film.stack", title: "Use your own videos",
                    message: "Import .mp4 or .mov files to play them behind your desktop icons. Sites like MotionBGs and MoeWalls have free car and anime loops you can download.",
                    primary: ("Import Video", onImport),
                    secondary: ("Open MotionBGs", { NSWorkspace.shared.open(URL(string: "https://motionbgs.com/tag:car/")!) }))
            default:
                if feed.errors.isEmpty {
                    EmptyStateView(
                        symbol: "photo.on.rectangle", title: "Nothing found",
                        message: "Try a different sort, switch between Photos and Live, or pick another interest.")
                } else {
                    EmptyStateView(
                        symbol: "wifi.exclamationmark", title: "Couldn't load wallpapers",
                        message: feed.errors.map(\.message).joined(separator: "\n"),
                        primary: ("Try Again", { Task { await feed.reload() } }))
                }
            }
        }
    }
}

struct EmptyStateView: View {
    let symbol: String
    let title: String
    let message: String
    var primary: (String, () -> Void)? = nil
    var secondary: (String, () -> Void)? = nil

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.secondary)
            Text(title).font(.title3.weight(.semibold))
            Text(message)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
            HStack {
                if let primary {
                    Button(primary.0, action: primary.1).buttonStyle(.borderedProminent)
                }
                if let secondary {
                    Button(secondary.0, action: secondary.1)
                }
            }
            .padding(.top, 4)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
