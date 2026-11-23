import Testing
@testable import WallpaperCore

@Suite struct ResolutionParserTests {
    @Test func parsesBracketedResolution() throws {
        let size = try #require(ResolutionParser.resolution(in: "Vestrahorn [3840x2160]"))
        #expect(size.width == 3840)
        #expect(size.height == 2160)
    }

    @Test func parsesSpacedAndUnicodeTimes() throws {
        let size = try #require(ResolutionParser.resolution(in: "Lake Bled (2560 × 1440)"))
        #expect(size.width == 2560)
        #expect(size.height == 1440)
    }

    @Test func returnsNilWithoutResolution() {
        #expect(ResolutionParser.resolution(in: "My cat") == nil)
    }

    @Test func cleanTitleStripsResolutionAndOC() {
        #expect(ResolutionParser.cleanTitle("[OC] Sunset at Big Sur [5000x3000]") == "Sunset at Big Sur")
    }
}
