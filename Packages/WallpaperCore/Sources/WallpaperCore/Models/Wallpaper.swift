import Foundation

public enum MediaKind: String, Codable, Sendable, CaseIterable, Hashable {
    case photo
    case video
}

public enum SourceID: String, Codable, Sendable, CaseIterable, Hashable {
    case reddit
    case wallhaven
    case pexels
    case bing
    case local

    public var displayName: String {
        switch self {
        case .reddit: "Reddit"
        case .wallhaven: "Wallhaven"
        case .pexels: "Pexels"
        case .bing: "Bing"
        case .local: "My Files"
        }
    }
}

/// One wallpaper from any source: a still photo or a looping video.
public struct Wallpaper: Codable, Hashable, Sendable, Identifiable {
    /// `"<source>:<id at the source>"`, unique across sources.
    public var id: String
    public var source: SourceID
    public var kind: MediaKind
    public var title: String
    public var author: String?
    public var thumbnailURL: URL
    /// The full image or the video file.
    public var mediaURL: URL
    /// Where to credit and view the original.
    public var pageURL: URL?
    public var width: Int?
    public var height: Int?
    /// Upvotes or favorites at the source, when it has them.
    public var score: Int?
    public var createdAt: Date?
    /// Seconds, for videos.
    public var duration: Double?
    /// The interests that produced this wallpaper in a feed.
    public var interestIDs: [String]

    public init(
        id: String,
        source: SourceID,
        kind: MediaKind,
        title: String,
        author: String? = nil,
        thumbnailURL: URL,
        mediaURL: URL,
        pageURL: URL? = nil,
        width: Int? = nil,
        height: Int? = nil,
        score: Int? = nil,
        createdAt: Date? = nil,
        duration: Double? = nil,
        interestIDs: [String] = []
    ) {
        self.id = id
        self.source = source
        self.kind = kind
        self.title = title
        self.author = author
        self.thumbnailURL = thumbnailURL
        self.mediaURL = mediaURL
        self.pageURL = pageURL
        self.width = width
        self.height = height
        self.score = score
        self.createdAt = createdAt
        self.duration = duration
        self.interestIDs = interestIDs
    }

    public var aspectRatio: Double? {
        guard let width, let height, height > 0 else { return nil }
        return Double(width) / Double(height)
    }

    public var resolutionLabel: String? {
        guard let width, let height else { return nil }
        return "\(width) × \(height)"
    }

    public var qualityBadge: String? {
        guard let width else { return nil }
        switch width {
        case 7680...: return "8K"
        case 5120...: return "5K"
        case 3840...: return "4K"
        case 2560...: return "QHD"
        case 1920...: return "HD"
        default: return nil
        }
    }

    /// File extension to save the media with: the URL's own when it is a
    /// known image/video type, otherwise a sensible default for the kind.
    public var preferredFileExtension: String {
        let ext = mediaURL.pathExtension.lowercased()
        switch kind {
        case .photo:
            return ["jpg", "jpeg", "png", "heic", "webp", "tiff"].contains(ext) ? ext : "jpg"
        case .video:
            return ["mp4", "mov", "m4v"].contains(ext) ? ext : "mp4"
        }
    }
}
