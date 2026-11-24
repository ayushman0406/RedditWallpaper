import SwiftUI
import WallpaperCore

/// A grid card: the image fills it; details and actions sit on top.
struct WallpaperCard: View {
    @Environment(AppModel.self) var model
    let wallpaper: Wallpaper
    let onOpen: () -> Void
    let onHide: () -> Void
    @State var isHovering = false

    var body: some View {
        Color.clear
            .aspectRatio(16.0 / 10.0, contentMode: .fit)
            .overlay { ThumbnailView(url: wallpaper.thumbnailURL) }
            .overlay {
                LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .center, endPoint: .bottom)
                    .opacity(isHovering || model.isBusy(wallpaper) ? 1 : 0.75)
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
                    if isHovering || model.isBusy(wallpaper) || model.isActive(wallpaper) {
                        SetWallpaperButton(wallpaper: wallpaper)
                    }
                }
                .padding(10)
            }
            .overlay(alignment: .topTrailing) {
                if isHovering || model.isFavorite(wallpaper) {
                    FavoriteButton(wallpaper: wallpaper).padding(8)
                }
            }
            .overlay(alignment: .topLeading) {
                InterestDots(ids: wallpaper.interestIDs).padding(10)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .onTapGesture(perform: onOpen)
            .onHover { isHovering = $0 }
            .animation(.easeOut(duration: 0.12), value: isHovering)
            .contextMenu { WallpaperMenuItems(wallpaper: wallpaper, onHide: onHide) }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(wallpaper.title)
    }
}

/// Small colored dots showing which interests a wallpaper came from.
struct InterestDots: View {
    @Environment(AppModel.self) var model
    let ids: [String]

    var body: some View {
        let interests = model.settings.selectedInterests.filter { ids.contains($0.id) }
        HStack(spacing: 4) {
            ForEach(interests) { interest in
                Circle()
                    .fill(interest.tint)
                    .frame(width: 8, height: 8)
                    .overlay(Circle().strokeBorder(.white.opacity(0.8), lineWidth: 1))
                    .help(interest.name)
            }
        }
    }
}
