import Foundation

/// Favorites, history, hidden wallpapers and imported videos.
public struct LibraryState: Codable, Equatable, Sendable {
    public static let historyLimit = 100

    public var favorites: [Wallpaper] = []
    /// Most recently applied first.
    public var history: [Wallpaper] = []
    public var localVideos: [Wallpaper] = []
    /// Wallpapers the user chose to never see again.
    public var blockedIDs: Set<String> = []

    public init() {}

    enum CodingKeys: String, CodingKey {
        case favorites, history, localVideos, blockedIDs
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        favorites = ((try? container.decodeIfPresent([Wallpaper].self, forKey: .favorites)) ?? nil) ?? []
        history = ((try? container.decodeIfPresent([Wallpaper].self, forKey: .history)) ?? nil) ?? []
        localVideos = ((try? container.decodeIfPresent([Wallpaper].self, forKey: .localVideos)) ?? nil) ?? []
        blockedIDs = ((try? container.decodeIfPresent(Set<String>.self, forKey: .blockedIDs)) ?? nil) ?? []
    }

    public func isFavorite(_ id: String) -> Bool {
        favorites.contains { $0.id == id }
    }

    public mutating func toggleFavorite(_ wallpaper: Wallpaper) {
        if let index = favorites.firstIndex(where: { $0.id == wallpaper.id }) {
            favorites.remove(at: index)
        } else {
            favorites.insert(wallpaper, at: 0)
        }
    }

    public mutating func recordApplied(_ wallpaper: Wallpaper) {
        history.removeAll { $0.id == wallpaper.id }
        history.insert(wallpaper, at: 0)
        if history.count > Self.historyLimit {
            history.removeLast(history.count - Self.historyLimit)
        }
    }

    public mutating func block(_ id: String) {
        blockedIDs.insert(id)
    }

    public mutating func addLocalVideo(_ wallpaper: Wallpaper) {
        guard !localVideos.contains(where: { $0.id == wallpaper.id }) else { return }
        localVideos.insert(wallpaper, at: 0)
    }

    public mutating func removeLocalVideo(id: String) {
        localVideos.removeAll { $0.id == id }
    }
}

/// Saves the library as a JSON file.
public final class LibraryFileStore {
    private let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public func load() -> LibraryState {
        guard let data = try? Data(contentsOf: fileURL),
              let state = try? JSONDecoder().decode(LibraryState.self, from: data) else {
            return LibraryState()
        }
        return state
    }

    public func save(_ state: LibraryState) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(state).write(to: fileURL, options: .atomic)
    }
}
