import Foundation
import Testing
@testable import WallpaperCore

@Suite struct FeedPagerTests {
    func page(_ ids: [String], exhausted: Bool = false) -> FeedPage {
        FeedPage(items: ids.map { wallpaper($0) }, errors: [], isExhausted: exhausted)
    }

    // Regression: opening Favorites while For You was still loading left the
    // spinner on forever.
    @Test func switchingToALocalListWhileLoadingStopsLoading() {
        var pager = FeedPager()
        pager.reset()
        let stale = pager.beginFirstPage()
        pager.reset()
        pager.showLocal([wallpaper("fav")])
        #expect(!pager.isLoading)
        pager.finish(page(["late"]), generation: stale)
        #expect(pager.items.map(\.id) == ["fav"])
        #expect(!pager.isLoading)
    }

    @Test func pagesAppendWithoutDuplicatesAndStaleResultsAreDropped() {
        var pager = FeedPager()
        let generation = pager.reset()
        _ = pager.beginFirstPage()
        pager.finish(page(["a", "b"]), generation: generation)
        #expect(pager.beginNextPage() == 2)
        #expect(pager.beginNextPage() == nil)
        pager.finish(page(["b", "c"], exhausted: true), generation: generation)
        #expect(pager.items.map(\.id) == ["a", "b", "c"])
        #expect(pager.beginNextPage() == nil)
        pager.finish(page(["old"]), generation: generation - 1)
        #expect(pager.items.map(\.id) == ["a", "b", "c"])
    }
}
