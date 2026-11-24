import Foundation
import WallpaperCore

/// Foundation also has a `SortOrder`; in this app it always means the feed's.
typealias SortOrder = WallpaperCore.SortOrder

/// A place in the Library sidebar (and the popover's chips).
enum LibraryCollection: Hashable, Identifiable {
    case forYou
    case today
    case redditPicks
    case interest(Interest)
    case search(String)
    case favorites
    case history
    case myVideos

    var id: String {
        switch self {
        case .forYou: "forYou"
        case .today: "today"
        case .redditPicks: "redditPicks"
        case .interest(let interest): "interest:\(interest.id)"
        case .search(let text): "search:\(text)"
        case .favorites: "favorites"
        case .history: "history"
        case .myVideos: "myVideos"
        }
    }

    var title: String {
        switch self {
        case .forYou: "For You"
        case .today: "Today on Bing"
        case .redditPicks: "Reddit Picks"
        case .interest(let interest): interest.name
        case .search(let text): "“\(text)”"
        case .favorites: "Favorites"
        case .history: "History"
        case .myVideos: "My Videos"
        }
    }

    var symbol: String {
        switch self {
        case .forYou: "sparkles"
        case .today: "sun.max.fill"
        case .redditPicks: "flame.fill"
        case .interest(let interest): interest.symbol
        case .search: "magnifyingglass"
        case .favorites: "heart.fill"
        case .history: "clock.arrow.circlepath"
        case .myVideos: "film.stack"
        }
    }

    /// Remote collections page through sources; the rest come from the library.
    var isRemote: Bool {
        switch self {
        case .favorites, .history, .myVideos: false
        default: true
        }
    }

    /// Whether the Photos / Live switch applies here.
    var supportsKindFilter: Bool {
        switch self {
        case .forYou, .interest, .search: true
        default: false
        }
    }

    /// Whether Top / New / Random means anything here.
    var supportsSort: Bool {
        switch self {
        case .forYou, .interest, .search, .redditPicks: true
        default: false
        }
    }

    func feedRequest(
        settings: AppSettings, kind: MediaKind, sort: SortOrder, page: Int, blocked: Set<String>, seed: String
    ) -> FeedRequest? {
        var request: FeedRequest
        switch self {
        case .forYou:
            let interests = settings.selectedInterests
            let scopes: [SourceQuery.Scope] = interests.isEmpty ? [.general] : interests.map { .interest($0) }
            request = FeedRequest(scopes: scopes, kind: kind, sort: sort, page: page)
            request.enabledSources = settings.enabledSources
        case .interest(let interest):
            request = FeedRequest(scopes: [.interest(interest)], kind: kind, sort: sort, page: page)
            request.enabledSources = settings.enabledSources
        case .search(let text):
            request = FeedRequest(scopes: [.search(text)], kind: kind, sort: sort, page: page)
            request.enabledSources = settings.enabledSources
        case .today:
            request = FeedRequest(scopes: [.general], kind: .photo, sort: .top, page: page)
            request.enabledSources = [.bing]
        case .redditPicks:
            request = FeedRequest(scopes: [.general], kind: .photo, sort: sort, page: page)
            request.enabledSources = [.reddit]
        case .favorites, .history, .myVideos:
            return nil
        }
        request.excludedIDs = blocked
        request.seed = seed
        return request
    }
}
