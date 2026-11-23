import AppKit
import SwiftUI
import WallpaperCore

/// First launch: welcome → interests → photos/live (+ optional Pexels key).
struct OnboardingView: View {
    @Environment(AppModel.self) var model
    @Environment(AppRouter.self) var router
    @State var step: Step = .welcome
    @State var heroURL: URL?
    @State var wantsPhotos = true
    @State var wantsLive = false
    @State var pexelsKey = ""

    enum Step { case welcome, interests, types }

    var body: some View {
        Group {
            switch step {
            case .welcome: welcome
            case .interests: interests
            case .types: types
            }
        }
        .frame(width: 760, height: 640)
        .task { await loadHero() }
    }

    // MARK: - Welcome

    private var welcome: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let heroURL {
                    ThumbnailView(url: heroURL)
                } else {
                    LinearGradient(colors: [.indigo, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
                }
            }
            .frame(width: 760, height: 640)
            .clipped()
            LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 14) {
                Text("Wallpapers for what you love")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Pick your interests and get photos and live wallpapers for them, one click away in your menu bar.")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(maxWidth: 520, alignment: .leading)
                Button("Get Started") {
                    withAnimation(.easeInOut(duration: 0.2)) { step = .interests }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .padding(.top, 6)
            }
            .padding(40)
        }
    }

    // MARK: - Interests

    private var interests: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("What are you into?")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text("Pick as many as you like. You can change them anytime in Settings or the Library.")
                    .foregroundStyle(.secondary)
            }
            ScrollView {
                InterestPicker().padding(.vertical, 2)
            }
            HStack {
                Button("Back") { step = .welcome }
                Spacer()
                let count = model.settings.selectedInterestIDs.count
                Text(count == 0 ? "Pick at least one" : "\(count) selected")
                    .foregroundStyle(.secondary)
                Button("Continue") { step = .types }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(count == 0)
            }
        }
        .padding(32)
    }

    // MARK: - Photos / Live

    private var types: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("What should we show?")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text("Photos work right away. Live wallpapers are looping videos that play behind your desktop icons.")
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 14) {
                TypeCard(
                    symbol: "photo.on.rectangle.angled", title: "Photos",
                    detail: "From Wallhaven, Reddit and Bing. No setup.", isOn: $wantsPhotos)
                TypeCard(
                    symbol: "play.rectangle.on.rectangle", title: "Live wallpapers",
                    detail: "Videos from Pexels, plus your own files.", isOn: $wantsLive)
            }
            if wantsLive {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Pexels API key").font(.headline)
                    Text("Free and instant: sign in at Pexels, open the API page and copy your key. You can also add it later in Settings → Sources.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    HStack {
                        TextField("Paste your key", text: $pexelsKey)
                            .textFieldStyle(.roundedBorder)
                        Link("Get a free key", destination: URL(string: "https://www.pexels.com/api/")!)
                    }
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.primary.opacity(0.04)))
            }
            Spacer()
            HStack {
                Button("Back") { step = .interests }
                Spacer()
                Button("Start Browsing", action: finish)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!wantsPhotos && !wantsLive)
            }
        }
        .padding(32)
    }

    private func finish() {
        model.settings.kindPreference = switch (wantsPhotos, wantsLive) {
        case (true, true): .both
        case (false, true): .live
        default: .photos
        }
        if !pexelsKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            model.setPexelsKey(pexelsKey)
        }
        router.finishOnboarding()
    }

    /// Today's Bing photo as the welcome backdrop; a gradient if offline.
    private func loadHero() async {
        guard heroURL == nil,
              let request = LibraryCollection.today.feedRequest(
                settings: model.settings, kind: .photo, sort: .top, page: 1, blocked: [], seed: "welcome")
        else { return }
        let page = await model.feedService().load(request)
        if let first = page.items.first {
            withAnimation(.easeInOut(duration: 0.6)) { heroURL = first.mediaURL }
        }
    }
}

private struct TypeCard: View {
    let symbol: String
    let title: String
    let detail: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: symbol)
                        .font(.system(size: 26, weight: .regular))
                        .foregroundStyle(isOn ? Color.accentColor : Color.secondary)
                    Spacer()
                    Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isOn ? Color.accentColor : Color.secondary)
                }
                Text(title).font(.headline)
                Text(detail).font(.callout).foregroundStyle(.secondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isOn ? Color.accentColor.opacity(0.1) : Color.primary.opacity(0.04)))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isOn ? Color.accentColor.opacity(0.6) : Color.clear, lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
