import AppKit
import SwiftUI
import UniformTypeIdentifiers
import WallpaperCore

/// The full Library window: collections in the sidebar, a sorted grid on the right.
struct LibraryView: View {
    @Environment(AppModel.self) var model
    @Environment(AppRouter.self) var router

    var body: some View {
        LibraryContent(model: model, router: router)
    }
}

private struct LibraryContent: View {
    let model: AppModel
    @Bindable var router: AppRouter
    @State var feed: FeedController
    @State var kind: MediaKind
    @State var sort: SortOrder = .top
    @State var searchText = ""
    @State var detail: Wallpaper?
    @State var isImporting = false
    @State var isEditingInterests = false

    init(model: AppModel, router: AppRouter) {
        self.model = model
        self.router = router
        _feed = State(initialValue: FeedController(model: model))
        _kind = State(initialValue: model.settings.kindPreference == .live ? .video : .photo)
    }

    private var selection: LibraryCollection { router.librarySelection }

    private var effectiveKind: MediaKind {
        switch selection {
        case .today, .redditPicks: .photo
        case .myVideos: .video
        default: kind
        }
    }

    private struct ReloadKey: Hashable {
        var collection: LibraryCollection
        var kind: MediaKind
        var sort: SortOrder
        var interests: [String]
        var sources: Set<SourceID>
        var hasKey: Bool
        var localCount: Int
        var favoriteCount: Int
        var historyCount: Int
    }

    private var reloadKey: ReloadKey {
        ReloadKey(
            collection: selection, kind: effectiveKind, sort: sort,
            interests: model.settings.selectedInterestIDs, sources: model.settings.enabledSources,
            hasKey: model.hasPexelsKey, localCount: model.library.localVideos.count,
            favoriteCount: selection == .favorites ? model.library.favorites.count : 0,
            historyCount: selection == .history ? model.library.history.count : 0)
    }

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 200, ideal: 228, max: 300)
        } detail: {
            WallpaperGrid(feed: feed, kind: effectiveKind, onOpen: { detail = $0 }, onImport: { isImporting = true })
                .navigationTitle(selection.title)
                .toolbar { toolbarContent }
        }
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search wallpapers")
        .onSubmit(of: .search) {
            let text = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty { router.librarySelection = .search(text) }
        }
        .task(id: reloadKey) {
            await feed.load(collection: selection, kind: effectiveKind, sort: sort)
        }
        .sheet(item: $detail) { wallpaper in
            WallpaperDetailView(wallpaper: wallpaper) { hidden in
                feed.remove(id: hidden.id)
            }
        }
        .sheet(isPresented: $isEditingInterests) {
            InterestEditorSheet()
        }
        .fileImporter(
            isPresented: $isImporting, allowedContentTypes: [.movie], allowsMultipleSelection: true
        ) { result in
            guard case let .success(urls) = result else { return }
            Task {
                for url in urls {
                    let didAccess = url.startAccessingSecurityScopedResource()
                    await model.importVideo(from: url)
                    if didAccess { url.stopAccessingSecurityScopedResource() }
                }
                router.librarySelection = .myVideos
            }
        }
        .frame(minWidth: 820, minHeight: 520)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: selectionBinding) {
            Section("Discover") {
                row(.forYou)
                if model.settings.enabledSources.contains(.bing) { row(.today) }
                if model.settings.enabledSources.contains(.reddit) { row(.redditPicks) }
            }
            Section("Your Interests") {
                ForEach(model.settings.selectedInterests) { interest in
                    row(.interest(interest))
                }
                Button {
                    isEditingInterests = true
                } label: {
                    Label("Edit Interests…", systemImage: "slider.horizontal.3")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            Section("Your Collection") {
                row(.favorites)
                row(.history)
                row(.myVideos)
            }
            if case .search = selection {
                Section("Search") { row(selection) }
            }
        }
        .listStyle(.sidebar)
    }

    private var selectionBinding: Binding<LibraryCollection?> {
        Binding(
            get: { router.librarySelection },
            set: { newValue in
                if let newValue { router.librarySelection = newValue }
            })
    }

    private func row(_ collection: LibraryCollection) -> some View {
        Label {
            Text(collection.title)
        } icon: {
            SymbolImage(collection.symbol, fallback: "star.fill")
                .foregroundStyle(collection.tint)
        }
        .tag(collection)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            if selection.supportsKindFilter {
                Picker("Type", selection: $kind) {
                    Label("Photos", systemImage: "photo").tag(MediaKind.photo)
                    Label("Live", systemImage: "play.rectangle").tag(MediaKind.video)
                }
                .pickerStyle(.segmented)
                .help("Show photos or live (video) wallpapers")
            }
            if selection.supportsSort {
                Picker("Sort", selection: $sort) {
                    ForEach(SortOrder.allCases, id: \.self) { order in
                        Text(order.displayName).tag(order)
                    }
                }
                .pickerStyle(.menu)
                .help("Sort order")
            }
            if selection == .myVideos {
                Button {
                    isImporting = true
                } label: {
                    Label("Import Video", systemImage: "plus")
                }
                .help("Import video files to use as live wallpapers")
            }
            Button {
                Task { await feed.reload() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .help("Load fresh results")
            .disabled(feed.isLoading)
        }
    }
}

/// "Edit Interests…" from the sidebar, without leaving the Library.
private struct InterestEditorSheet: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your interests").font(.title2.weight(.semibold))
            Text("Pick what you want to see. Changes apply right away.")
                .foregroundStyle(.secondary)
            ScrollView { InterestPicker().padding(.vertical, 2) }
            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 640, height: 560)
    }
}
