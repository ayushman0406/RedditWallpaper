import Foundation

/// Pexels photos and videos. Free, but every request needs the user's API key
/// (200 requests per hour by default). Content must credit Pexels and the author.
public struct PexelsSource: WallpaperSource {
    public let id = SourceID.pexels
    let apiKey: String?
    let maxVideoWidth: Int

    public init(apiKey: String?, maxVideoWidth: Int = 3840) {
        self.apiKey = apiKey?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.maxVideoWidth = maxVideoWidth
    }

    private var key: String? {
        guard let apiKey, !apiKey.isEmpty else { return nil }
        return apiKey
    }

    public func supports(_ query: SourceQuery) -> Bool {
        key != nil
    }

    public func makeRequest(for query: SourceQuery) throws -> URLRequest {
        guard let key else { throw URLError(.userAuthenticationRequired) }
        let term = query.searchText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let page = String(query.sourcePage)
        let url: URL = switch (query.kind, term.isEmpty) {
        case (.photo, true):
            try RequestBuilder.url("https://api.pexels.com/v1/curated", [("per_page", "30"), ("page", page)])
        case (.photo, false):
            try RequestBuilder.url("https://api.pexels.com/v1/search", [
                ("query", term), ("orientation", "landscape"), ("size", "medium"),
                ("per_page", "30"), ("page", page),
            ])
        case (.video, true):
            try RequestBuilder.url("https://api.pexels.com/v1/videos/popular", [
                ("min_width", "1920"), ("per_page", "20"), ("page", page),
            ])
        case (.video, false):
            try RequestBuilder.url("https://api.pexels.com/v1/videos/search", [
                ("query", term), ("orientation", "landscape"), ("size", "medium"),
                ("per_page", "20"), ("page", page),
            ])
        }
        var request = RequestBuilder.request(url)
        request.setValue(key, forHTTPHeaderField: "Authorization")
        return request
    }

    // MARK: - Responses

    struct PhotoResponse: Decodable {
        let photos: [Photo]
    }

    struct Photo: Decodable {
        let id: Int
        let width: Int?
        let height: Int?
        let url: String?
        let photographer: String?
        let alt: String?
        let src: PhotoSource
    }

    struct PhotoSource: Decodable {
        let original: String
        let large: String?
        let medium: String?
        let landscape: String?
    }

    struct VideoResponse: Decodable {
        let videos: [Video]
    }

    struct Video: Decodable {
        let id: Int
        let url: String?
        let image: String?
        let duration: Double?
        let user: User?
        let videoFiles: [VideoFile]
    }

    struct User: Decodable {
        let name: String?
    }

    public struct VideoFile: Decodable, Sendable, Equatable {
        public let quality: String?
        public let fileType: String?
        public let width: Int?
        public let height: Int?
        public let link: URL
    }

    public func parse(_ data: Data, for query: SourceQuery) throws -> [Wallpaper] {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        switch query.kind {
        case .photo:
            return try decoder.decode(PhotoResponse.self, from: data).photos.compactMap { photo -> Wallpaper? in
                guard let media = URL(string: photo.src.original) else { return nil }
                let thumbnail = (photo.src.medium ?? photo.src.landscape ?? photo.src.large)
                    .flatMap(URL.init(string:)) ?? media
                let alt = photo.alt?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return Wallpaper(
                    id: "pexels:photo-\(photo.id)", source: .pexels, kind: .photo,
                    title: alt.isEmpty ? "Photo by \(photo.photographer ?? "a Pexels photographer")" : alt,
                    author: photo.photographer,
                    thumbnailURL: thumbnail, mediaURL: media, pageURL: photo.url.flatMap(URL.init(string:)),
                    width: photo.width, height: photo.height)
            }
        case .video:
            return try decoder.decode(VideoResponse.self, from: data).videos.compactMap { video -> Wallpaper? in
                guard let file = Self.bestVideoFile(video.videoFiles, maxWidth: maxVideoWidth) else { return nil }
                let page = video.url.flatMap(URL.init(string:))
                let title = page.flatMap(Self.title(fromPageURL:))
                    ?? "Video by \(video.user?.name ?? "a Pexels creator")"
                return Wallpaper(
                    id: "pexels:video-\(video.id)", source: .pexels, kind: .video,
                    title: title, author: video.user?.name,
                    thumbnailURL: video.image.flatMap(URL.init(string:)) ?? file.link,
                    mediaURL: file.link, pageURL: page,
                    width: file.width, height: file.height, duration: video.duration)
            }
        }
    }

    /// The largest MP4 no wider than `maxWidth`, else the smallest one.
    /// Streaming (HLS) entries have no width and are skipped.
    public static func bestVideoFile(_ files: [VideoFile], maxWidth: Int) -> VideoFile? {
        let usable = files.filter { file in
            (file.fileType ?? "video/mp4") == "video/mp4"
                && file.width != nil
                && file.quality != "hls"
                && file.link.pathExtension.lowercased() != "m3u8"
        }
        let fitting = usable.filter { ($0.width ?? 0) <= maxWidth }
        if let best = fitting.max(by: { ($0.width ?? 0) < ($1.width ?? 0) }) { return best }
        return usable.min(by: { ($0.width ?? 0) < ($1.width ?? 0) })
    }

    /// Pexels video pages describe the clip in their slug:
    /// `/video/aerial-view-of-surfers-1234567/` → "Aerial view of surfers".
    public static func title(fromPageURL url: URL) -> String? {
        var words = url.lastPathComponent.split(separator: "-").map(String.init)
        while let last = words.last, last.allSatisfy(\.isNumber) {
            words.removeLast()
        }
        guard !words.isEmpty else { return nil }
        let sentence = words.joined(separator: " ")
        return sentence.prefix(1).uppercased() + sentence.dropFirst()
    }
}
