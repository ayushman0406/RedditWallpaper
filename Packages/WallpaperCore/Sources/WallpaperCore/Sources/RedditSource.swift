import Foundation

/// Reddit posts through meme-api.com (Reddit closed free API access to new
/// apps in 2026). meme-api returns a random sample of recent image posts.
public struct RedditSource: WallpaperSource {
    public let id = SourceID.reddit
    let count: Int

    public init(count: Int = 30) {
        self.count = count
    }

    func subreddits(for query: SourceQuery) -> [String] {
        switch query.scope {
        case .general: InterestCatalog.redditPicksSubreddits
        case .interest(let interest): interest.subreddits
        case .search: []
        }
    }

    public func supports(_ query: SourceQuery) -> Bool {
        query.kind == .photo && !subreddits(for: query).isEmpty
    }

    public func makeRequest(for query: SourceQuery) throws -> URLRequest {
        let subreddits = subreddits(for: query)
        guard !subreddits.isEmpty else { throw URLError(.unsupportedURL) }
        let subreddit = subreddits[(max(query.page, 1) - 1) % subreddits.count]
        guard let url = URL(string: "https://meme-api.com/gimme/\(subreddit)/\(count)") else {
            throw URLError(.badURL)
        }
        return RequestBuilder.request(url)
    }

    struct Response: Decodable {
        let memes: [Post]
    }

    struct Post: Decodable {
        let postLink: String
        let title: String
        let url: String
        let nsfw: Bool?
        let spoiler: Bool?
        let author: String?
        let ups: Int?
        let preview: [String]?
    }

    public func parse(_ data: Data, for query: SourceQuery) throws -> [Wallpaper] {
        let response = try JSONDecoder().decode(Response.self, from: data)
        var items = response.memes.compactMap { post -> Wallpaper? in
            guard post.nsfw != true, post.spoiler != true,
                  let media = URL(string: post.url),
                  ["jpg", "jpeg", "png"].contains(media.pathExtension.lowercased()) else { return nil }
            let previews = post.preview ?? []
            let thumbnail = (previews.first { $0.contains("width=640") } ?? previews.last)
                .flatMap(URL.init(string:)) ?? media
            let size = ResolutionParser.resolution(in: post.title)
            let title = ResolutionParser.cleanTitle(post.title)
            let nativeID = URL(string: post.postLink)?.lastPathComponent ?? post.postLink
            return Wallpaper(
                id: "reddit:\(nativeID)", source: .reddit, kind: .photo,
                title: title.isEmpty ? "Reddit wallpaper" : title,
                author: post.author.map { "u/\($0)" },
                thumbnailURL: thumbnail, mediaURL: media, pageURL: URL(string: post.postLink),
                width: size?.width, height: size?.height, score: post.ups)
        }
        if query.sort == .top {
            items.sort { ($0.score ?? 0) > ($1.score ?? 0) }
        }
        return items
    }

    /// meme-api explains failures in a JSON `message`, e.g.
    /// "r/carporn has no Posts with Images".
    public func errorMessage(status: Int, data: Data) -> String {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let message = json["message"] as? String {
            return message
        }
        return "HTTP \(status)"
    }
}
