import Foundation

/// Something the user likes, and how to find wallpapers for it.
public struct Interest: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var name: String
    /// SF Symbol name.
    public var symbol: String
    /// Queries for searchable sources, rotated page by page for variety.
    public var searchTerms: [String]
    /// Wallhaven category bits: general, anime, people ("100" = general only).
    public var wallhavenCategories: String
    /// On-topic wallpaper subreddits; empty when Reddit has none worth using.
    public var subreddits: [String]
    public var isCustom: Bool

    public init(
        id: String,
        name: String,
        symbol: String,
        searchTerms: [String],
        wallhavenCategories: String = "111",
        subreddits: [String] = [],
        isCustom: Bool = false
    ) {
        self.id = id
        self.name = name
        self.symbol = symbol
        self.searchTerms = searchTerms
        self.wallhavenCategories = wallhavenCategories
        self.subreddits = subreddits
        self.isCustom = isCustom
    }

    /// An interest the user typed, e.g. "Real Madrid". Nil when the text has
    /// no letters or digits.
    public static func custom(named text: String) -> Interest? {
        let name = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let identifier = Self.slug(name)
        guard !name.isEmpty, !identifier.isEmpty else { return nil }
        return Interest(
            id: "custom:\(identifier)", name: name, symbol: "star.fill",
            searchTerms: [name], wallhavenCategories: "111", subreddits: [], isCustom: true)
    }

    static func slug(_ text: String) -> String {
        var result = ""
        var lastWasDash = false
        for character in text.lowercased() {
            if character.isLetter || character.isNumber {
                result.append(character)
                lastWasDash = false
            } else if !lastWasDash, !result.isEmpty {
                result.append("-")
                lastWasDash = true
            }
        }
        while result.hasSuffix("-") { result.removeLast() }
        return result
    }

    /// The search term for a feed page: page 1 uses the first term, page 2 the second, …
    public func searchTerm(forPage page: Int) -> String? {
        guard !searchTerms.isEmpty else { return nil }
        return searchTerms[(max(page, 1) - 1) % searchTerms.count]
    }

    /// The page to ask the source for, given the rotation in `searchTerm(forPage:)`.
    public func sourcePage(forPage page: Int) -> Int {
        (max(page, 1) - 1) / max(searchTerms.count, 1) + 1
    }
}

public enum InterestCatalog {
    public static let redditPicksSubreddits = ["wallpaper", "wallpapers", "WidescreenWallpaper"]

    public static let presets: [Interest] = [
        Interest(id: "football", name: "Football", symbol: "soccerball",
                 searchTerms: ["soccer", "football stadium", "football"], wallhavenCategories: "100"),
        Interest(id: "americanFootball", name: "American Football", symbol: "football.fill",
                 searchTerms: ["american football", "nfl"], wallhavenCategories: "100"),
        Interest(id: "cars", name: "Cars", symbol: "car.fill",
                 searchTerms: ["sports car", "supercar", "jdm", "car"], wallhavenCategories: "100"),
        Interest(id: "surfing", name: "Surfing", symbol: "figure.surfing",
                 searchTerms: ["surfing", "surfer", "ocean waves"], wallhavenCategories: "100"),
        Interest(id: "motorbikes", name: "Motorbikes", symbol: "motorcycle",
                 searchTerms: ["motorcycle", "superbike"], wallhavenCategories: "100"),
        Interest(id: "bicycles", name: "Bicycles", symbol: "bicycle",
                 searchTerms: ["cycling", "mountain bike", "bicycle"], wallhavenCategories: "100"),
        Interest(id: "superheroes", name: "Superheroes", symbol: "bolt.shield.fill",
                 searchTerms: ["superhero", "marvel", "dc comics", "spider-man", "batman"], wallhavenCategories: "111"),
        Interest(id: "onePiece", name: "One Piece", symbol: "sailboat.fill",
                 searchTerms: ["one piece", "monkey d. luffy", "roronoa zoro"], wallhavenCategories: "110"),
        Interest(id: "anime", name: "Anime", symbol: "sparkles",
                 searchTerms: ["anime", "anime landscape"], wallhavenCategories: "010", subreddits: ["Animewallpaper"]),
        Interest(id: "nature", name: "Nature", symbol: "leaf.fill",
                 searchTerms: ["nature", "landscape", "forest"], wallhavenCategories: "100", subreddits: ["EarthPorn"]),
        Interest(id: "space", name: "Space", symbol: "moon.stars.fill",
                 searchTerms: ["space", "galaxy", "nebula"], wallhavenCategories: "100", subreddits: ["spaceporn"]),
        Interest(id: "cities", name: "Cities", symbol: "building.2.fill",
                 searchTerms: ["city", "skyline", "cityscape"], wallhavenCategories: "100", subreddits: ["CityPorn"]),
        Interest(id: "gaming", name: "Gaming", symbol: "gamecontroller.fill",
                 searchTerms: ["video games", "gaming"], wallhavenCategories: "111"),
        Interest(id: "minimal", name: "Minimal", symbol: "circle.lefthalf.filled",
                 searchTerms: ["minimalism", "minimalist"], wallhavenCategories: "100", subreddits: ["MinimalWallpaper"]),
    ]

    public static func preset(id: String) -> Interest? {
        presets.first { $0.id == id }
    }
}
