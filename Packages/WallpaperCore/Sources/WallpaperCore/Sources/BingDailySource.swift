import Foundation

/// Bing's photo of the day (the last eight days), in 4K. The feed is
/// unofficial but long-lived; it needs no key.
public struct BingDailySource: WallpaperSource {
    public let id = SourceID.bing
    let market: String

    public init(market: String = "en-US") {
        self.market = market
    }

    public func supports(_ query: SourceQuery) -> Bool {
        guard query.kind == .photo, query.page == 1 else { return false }
        if case .general = query.scope { return true }
        return false
    }

    public func makeRequest(for query: SourceQuery) throws -> URLRequest {
        RequestBuilder.request(try RequestBuilder.url(
            "https://www.bing.com/HPImageArchive.aspx",
            [("format", "js"), ("idx", "0"), ("n", "8"), ("mkt", market)]))
    }

    struct Response: Decodable {
        let images: [Image]
    }

    struct Image: Decodable {
        let startdate: String
        let urlbase: String
        let copyright: String?
        let copyrightlink: String?
        let title: String?
    }

    public func parse(_ data: Data, for query: SourceQuery) throws -> [Wallpaper] {
        let response = try JSONDecoder().decode(Response.self, from: data)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyyMMdd"
        return response.images.compactMap { image -> Wallpaper? in
            guard let media = URL(string: "https://www.bing.com\(image.urlbase)_UHD.jpg"),
                  let thumbnail = URL(string: "https://www.bing.com\(image.urlbase)_800x480.jpg") else { return nil }
            return Wallpaper(
                id: "bing:\(image.startdate)", source: .bing, kind: .photo,
                title: image.title ?? "Bing photo of the day", author: image.copyright,
                thumbnailURL: thumbnail, mediaURL: media, pageURL: image.copyrightlink.flatMap(URL.init(string:)),
                width: 3840, height: 2160, createdAt: formatter.date(from: image.startdate))
        }
    }
}
