import Testing
@testable import WallpaperCore

@Suite struct SeededRandomTests {
    @Test func sameSeedSameOrder() {
        let items = Array(0..<20)
        #expect(items.seededShuffle(seed: "abc") == items.seededShuffle(seed: "abc"))
    }

    @Test func differentSeedDifferentOrder() {
        let items = Array(0..<20)
        #expect(items.seededShuffle(seed: "abc") != items.seededShuffle(seed: "xyz"))
        #expect(items.seededShuffle(seed: "abc").sorted() == items)
    }
}
