import AppKit
import SwiftUI
import WallpaperCore

/// An SF Symbol that falls back to another symbol when the name doesn't
/// exist on this macOS version.
struct SymbolImage: View {
    let name: String
    let fallback: String

    init(_ name: String, fallback: String = "photo") {
        self.name = name
        self.fallback = fallback
    }

    var body: some View {
        Image(systemName: Self.resolve(name, fallback: fallback))
    }

    static func resolve(_ name: String, fallback: String) -> String {
        NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil ? name : fallback
    }
}

extension Interest {
    /// Each interest has its own color, used on tiles, chips and sidebar icons.
    var tint: Color {
        switch id {
        case "football": .green
        case "americanFootball": .brown
        case "cars": .red
        case "surfing": .cyan
        case "motorbikes": .orange
        case "bicycles": .mint
        case "superheroes": .indigo
        case "onePiece": .yellow
        case "anime": .pink
        case "nature": .green
        case "space": .purple
        case "cities": .blue
        case "gaming": .teal
        case "minimal": .gray
        default: .accentColor
        }
    }
}

extension LibraryCollection {
    var tint: Color {
        switch self {
        case .interest(let interest): interest.tint
        case .forYou: .accentColor
        case .today: .orange
        case .redditPicks: .orange
        case .favorites: .pink
        case .search: .accentColor
        case .history, .myVideos: .secondary
        }
    }
}
