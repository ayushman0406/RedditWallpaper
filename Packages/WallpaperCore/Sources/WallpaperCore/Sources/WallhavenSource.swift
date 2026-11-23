import Foundation

/// wallhaven.cc's public API: safe-for-work search needs no key
/// (45 requests per minute).
public struct WallhavenSource: WallpaperSource {
    public let id = SourceID.wallhaven

    public init() {}

    public func supports(_ query: SourceQuery) -> Bool {
        query.kind == .photo
    }

    public func makeRequest(for query: SourceQuery) throws -> URLRequest {
        let term = query.searchText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var items: [(String, String)] = []
        if !term.isEmpty { items.append(("q", term)) }
        let categories: String
        if case let .interest(interest) = query.scope {
            categories = interest.wallhavenCategories
        } else {
            categories = "111"
        }
        items.append(("categories", categories))
        items.append(("purity", "100"))
        switch query.sort {
        case .top:
            // "toplist" over a month is empty for niche searches, so searches
            // use all-time favorites instead.
            if term.isEmpty {
                items += [("sorting", "toplist"), ("topRange", "1M")]
            } else {
                items.append(("sorting", "favorites"))
            }
        case .new:
            items.append(("sorting", "date_added"))
        case .random:
            items += [("sorting", "random"), ("seed", Self.seed(from: query.seed))]
        }
        items += [
            ("order", "desc"),
            ("atleast", "\(query.minWidth)x\(query.minHeight)"),
            ("page", String(query.sourcePage)),
        ]
        return RequestBuilder.request(try RequestBuilder.url("https://wallhaven.cc/api/v1/search", items))
    }

    /// Wallhaven seeds must be six letters or digits.
    static func seed(from text: String) -> String {
        let alphabet = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        var generator = SeededGenerator(seed: text)
        return String((0..<6).map { _ in alphabet[Int(generator.next() % UInt64(alphabet.count))] })
    }

    struct Response: Decodable {
        let data: [Item]
    }

    struct Item: Decodable {
        let id: String
        let url: String?
        let purity: String?
        let dimensionX: Int?
        let dimensionY: Int?
        let favorites: Int?
        let createdAt: String?
        let path: String
        let thumbs: Thumbs?
    }

    struct Thumbs: Decodable {
        let large: String?
        let original: String?
        let small: String?
    }

    public func parse(_ data: Data, for query: SourceQuery) throws -> [Wallpaper] {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let response = try decoder.decode(Response.self, from: data)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let label: String = switch query.scope {
        case .interest(let interest): interest.name
        case .search(let text): text
        case .general: "Wallhaven"
        }
        return response.data.compactMap { item -> Wallpaper? in
            guard item.purity == "sfw", let media = URL(string: item.path) else { return nil }
            let thumbnail = (item.thumbs?.large ?? item.thumbs?.original ?? item.thumbs?.small)
                .flatMap(URL.init(string:)) ?? media
            return Wallpaper(
                id: "wallhaven:\(item.id)", source: .wallhaven, kind: .photo,
                title: "\(label) wallpaper",
                thumbnailURL: thumbnail, mediaURL: media, pageURL: item.url.flatMap(URL.init(string:)),
                width: item.dimensionX, height: item.dimensionY, score: item.favorites,
                createdAt: item.createdAt.flatMap(formatter.date(from:)))
        }
    }
}
