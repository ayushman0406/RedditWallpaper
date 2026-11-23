import Foundation
import Observation
import WallpaperCore

/// Loads and pages one collection for a view (the popover or the Library).
/// The paging rules live in `FeedPager`, where they are unit-tested.
@Observable
final class FeedController {
    private(set) var pager = FeedPager()
    private(set) var collection: LibraryCollection = .forYou
    private(set) var kind: MediaKind = .photo
    private(set) var sort: SortOrder = .top

    var items: [Wallpaper] { pager.items }
    var isLoading: Bool { pager.isLoading }
    var errors: [SourceError] { pager.errors }
    var isExhausted: Bool { pager.isExhausted }
    var hasLoaded: Bool { pager.hasLoaded }

    @ObservationIgnored private weak var model: AppModel?
    @ObservationIgnored private var seed = "w4llp4"

    init(model: AppModel) {
        self.model = model
    }

    func load(collection: LibraryCollection, kind: MediaKind, sort: SortOrder) async {
        self.collection = collection
        self.kind = kind
        self.sort = sort
        seed = String(UUID().uuidString.prefix(8))
        pager.reset()
        guard let model else { return }
        guard collection.isRemote else {
            pager.showLocal(model.localItems(for: collection))
            return
        }
        let generation = pager.beginFirstPage()
        await fetch(page: 1, generation: generation)
    }

    func reload() async {
        await load(collection: collection, kind: kind, sort: sort)
    }

    func loadMore() async {
        guard collection.isRemote, let page = pager.beginNextPage() else { return }
        await fetch(page: page, generation: pager.generation)
    }

    /// Drops an item from the visible list (after "Hide").
    func remove(id: String) {
        pager.remove(id: id)
    }

    private func fetch(page: Int, generation: Int) async {
        guard let model, let request = collection.feedRequest(
            settings: model.settings, kind: kind, sort: sort, page: page,
            blocked: model.library.blockedIDs, seed: seed)
        else {
            pager.finish(FeedPage(items: [], errors: [], isExhausted: true), generation: generation)
            return
        }
        let result = await model.feedService().load(request)
        // A newer load started while this one was in flight: the pager drops it.
        pager.finish(result, generation: generation)
    }
}
