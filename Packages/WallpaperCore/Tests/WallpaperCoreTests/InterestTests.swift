import Testing
@testable import WallpaperCore

@Suite struct InterestTests {
    @Test func presetsIncludeUserInterests() {
        let ids = Set(InterestCatalog.presets.map(\.id))
        for id in ["football", "cars", "surfing", "motorbikes", "bicycles", "superheroes", "onePiece"] {
            #expect(ids.contains(id), "missing preset \(id)")
        }
    }

    @Test func presetIDsAreUnique() {
        let ids = InterestCatalog.presets.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test func everyPresetHasSearchTerms() {
        for interest in InterestCatalog.presets {
            #expect(!interest.searchTerms.isEmpty, "\(interest.id) has no search terms")
            #expect(interest.wallhavenCategories.count == 3, "\(interest.id) categories")
            #expect(!interest.isCustom)
        }
    }

    @Test func presetLookup() {
        #expect(InterestCatalog.preset(id: "cars")?.name == "Cars")
        #expect(InterestCatalog.preset(id: "onePiece")?.wallhavenCategories == "110")
        #expect(InterestCatalog.preset(id: "nope") == nil)
    }

    @Test func customInterestSlug() throws {
        let interest = try #require(Interest.custom(named: "  Real Madrid "))
        #expect(interest.id == "custom:real-madrid")
        #expect(interest.name == "Real Madrid")
        #expect(interest.searchTerms == ["Real Madrid"])
        #expect(interest.wallhavenCategories == "111")
        #expect(interest.subreddits.isEmpty)
        #expect(interest.isCustom)
        #expect(Interest.custom(named: "Tom & Jerry")?.id == "custom:tom-jerry")
    }

    @Test func customInterestRejectsBlank() {
        #expect(Interest.custom(named: "   ") == nil)
        #expect(Interest.custom(named: "&&") == nil)
    }

    @Test func searchTermRotation() {
        let interest = Interest(
            id: "x", name: "X", symbol: "star", searchTerms: ["a", "b", "c"],
            wallhavenCategories: "111", subreddits: [], isCustom: false)
        #expect(interest.searchTerm(forPage: 1) == "a")
        #expect(interest.sourcePage(forPage: 1) == 1)
        #expect(interest.searchTerm(forPage: 2) == "b")
        #expect(interest.sourcePage(forPage: 2) == 1)
        #expect(interest.searchTerm(forPage: 4) == "a")
        #expect(interest.sourcePage(forPage: 4) == 2)
    }
}
