import Testing
@testable import WallpaperCore

@Suite struct QueryStringTests {
    @Test func encodesReservedCharacters() {
        #expect(QueryString.encode([("q", "Tom & Jerry"), ("x", "C++")]) == "q=Tom%20%26%20Jerry&x=C%2B%2B")
    }

    @Test func keepsUnreservedCharacters() {
        #expect(QueryString.encode([("a", "one-piece_1.0~")]) == "a=one-piece_1.0~")
    }
}
