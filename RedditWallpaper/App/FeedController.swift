import Foundation
import Observation
import WallpaperCore

/// Loads and pages one collection for a view (the popover or the Library).
@Observable
final class FeedController {
    private(set) var items: [Wallpaper] = []
    private(set) var isLoading = false
    private(set) var errors: [SourceError] = []
    private(set) var isExhausted = false
    private(set) var collection: LibraryCollection = .forYou
    private(set) var kind: MediaKind = .photo
    private(set) var sort: SortOrder = .top
    private(set) var hasLoaded = false

    @ObservationIgnored private weak var model: AppModel?
    @ObservationIgnored private var page = 1
    @ObservationIgnored private var seed = "w4llp4"
    @ObservationIgnored private var generation = 0

    init(model: AppModel) {
        self.model = model
    }

    func load(collection: LibraryCollection, kind: MediaKind, sort: SortOrder) async {
        self.collection = collection
        self.kind = kind
        self.sort = sort
        page = 1
        seed = String(UUID().uuidString.prefix(8))
        generation += 1
        items = []
        errors = []
        isExhausted = false
        await fetch(generation: generation)
    }

    func reload() async {
        await load(collection: collection, kind: kind, sort: sort)
    }

    func loadMore() async {
        guard hasLoaded, !isLoading, !isExhausted, collection.isRemote else { return }
        page += 1
        await fetch(generation: generation)
    }

    /// Drops an item from the visible list (after "Hide").
    func remove(id: String) {
        items.removeAll { $0.id == id }
    }

    private func fetch(generation: Int) async {
        guard let model else { return }
        guard collection.isRemote else {
            items = model.localItems(for: collection)
            isExhausted = true
            hasLoaded = true
            return
        }
        guard let request = collection.feedRequest(
            settings: model.settings, kind: kind, sort: sort, page: page,
            blocked: model.library.blockedIDs, seed: seed) else { return }
        isLoading = true
        let result = await model.feedService().load(request)
        // A newer load started while this one was in flight; drop the result.
        guard generation == self.generation else { return }
        let known = Set(items.map(\.id))
        items.append(contentsOf: result.items.filter { !known.contains($0.id) })
        errors = result.errors
        isExhausted = result.isExhausted
        isLoading = false
        hasLoaded = true
    }
}
