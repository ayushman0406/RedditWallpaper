import Foundation
import Testing
@testable import WallpaperCore

@Suite struct LibraryStateTests {
    @Test func toggleFavoriteAddsThenRemoves() {
        var state = LibraryState()
        let item = wallpaper("fav")
        state.toggleFavorite(item)
        #expect(state.isFavorite("fav"))
        #expect(state.favorites.first?.id == "fav")
        state.toggleFavorite(item)
        #expect(!state.isFavorite("fav"))
        #expect(state.favorites.isEmpty)
    }

    @Test func recordAppliedMovesToFrontAndCaps() {
        var state = LibraryState()
        for index in 0..<101 { state.recordApplied(wallpaper("w\(index)")) }
        #expect(state.history.count == LibraryState.historyLimit)
        #expect(state.history.first?.id == "w100")
        #expect(!state.history.contains { $0.id == "w0" })
        state.recordApplied(wallpaper("w50"))
        #expect(state.history.first?.id == "w50")
        #expect(state.history.filter { $0.id == "w50" }.count == 1)
        #expect(state.history.count == LibraryState.historyLimit)
    }

    @Test func blockAndLocalVideos() {
        var state = LibraryState()
        state.block("bad")
        #expect(state.blockedIDs == ["bad"])
        let video = Wallpaper(
            id: "local:abc", source: .local, kind: .video, title: "Mine",
            thumbnailURL: URL(fileURLWithPath: "/tmp/a.jpg"), mediaURL: URL(fileURLWithPath: "/tmp/a.mp4"))
        state.addLocalVideo(video)
        state.addLocalVideo(video)
        #expect(state.localVideos.count == 1)
        state.removeLocalVideo(id: "local:abc")
        #expect(state.localVideos.isEmpty)
    }

    @Test func fileStoreRoundTrip() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = LibraryFileStore(fileURL: directory.appendingPathComponent("library.json"))
        var state = LibraryState()
        state.toggleFavorite(wallpaper("fav"))
        state.recordApplied(wallpaper("hist"))
        state.block("nope")
        try store.save(state)
        #expect(store.load() == state)
    }

    @Test func missingFileLoadsEmptyState() {
        let store = LibraryFileStore(fileURL: URL(fileURLWithPath: "/nonexistent-\(UUID().uuidString)/library.json"))
        #expect(store.load() == LibraryState())
    }
}
