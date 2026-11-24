import Foundation

/// The paging state behind one feed view (the popover or the Library grid).
/// Each `reset()` starts a new generation, and results that belong to an
/// older generation are dropped, so switching collections never shows a
/// stale page.
public struct FeedPager: Sendable {
    public private(set) var items: [Wallpaper] = []
    public private(set) var errors: [SourceError] = []
    public private(set) var isLoading = false
    public private(set) var isExhausted = false
    public private(set) var hasLoaded = false
    public private(set) var page = 1
    public private(set) var generation = 0

    public init() {}

    /// Clears the list for a new collection; returns its generation. A load
    /// still in flight belongs to the old generation, so nothing is loading
    /// until the new collection starts its own.
    @discardableResult
    public mutating func reset() -> Int {
        generation += 1
        page = 1
        items = []
        errors = []
        isExhausted = false
        isLoading = false
        return generation
    }

    /// Shows a list kept on this Mac (favorites, history, my videos).
    public mutating func showLocal(_ local: [Wallpaper]) {
        items = local
        isExhausted = true
        hasLoaded = true
    }

    /// Marks page 1 as loading; returns the generation its result must carry.
    public mutating func beginFirstPage() -> Int {
        isLoading = true
        return generation
    }

    /// Moves to the next page when there is one and nothing is loading;
    /// returns the page to fetch.
    public mutating func beginNextPage() -> Int? {
        guard hasLoaded, !isLoading, !isExhausted else { return nil }
        page += 1
        isLoading = true
        return page
    }

    /// Adds a finished page, unless a newer `reset()` happened since.
    public mutating func finish(_ result: FeedPage, generation: Int) {
        guard generation == self.generation else { return }
        let known = Set(items.map(\.id))
        items.append(contentsOf: result.items.filter { !known.contains($0.id) })
        errors = result.errors
        isExhausted = result.isExhausted
        isLoading = false
        hasLoaded = true
    }

    /// Drops an item from the visible list (after "Hide").
    public mutating func remove(id: String) {
        items.removeAll { $0.id == id }
    }
}
