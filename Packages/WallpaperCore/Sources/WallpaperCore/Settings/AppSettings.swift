import Foundation

public enum KindPreference: String, Codable, Sendable, CaseIterable {
    case photos
    case live
    case both
}

public enum AutoChangeInterval: String, Codable, Sendable, CaseIterable {
    case off
    case every15Minutes
    case hourly
    case every3Hours
    case daily

    public var seconds: TimeInterval? {
        switch self {
        case .off: nil
        case .every15Minutes: 15 * 60
        case .hourly: 60 * 60
        case .every3Hours: 3 * 60 * 60
        case .daily: 24 * 60 * 60
        }
    }

    public var displayName: String {
        switch self {
        case .off: "Never"
        case .every15Minutes: "Every 15 minutes"
        case .hourly: "Every hour"
        case .every3Hours: "Every 3 hours"
        case .daily: "Every day"
        }
    }

    public func isDue(lastChange: Date?, now: Date) -> Bool {
        guard let seconds else { return false }
        guard let lastChange else { return true }
        return now.timeIntervalSince(lastChange) >= seconds
    }
}

public enum VideoQuality: Int, Codable, Sendable, CaseIterable {
    case hd1080 = 1920
    case qhd1440 = 2560
    case uhd4K = 3840

    public var displayName: String {
        switch self {
        case .hd1080: "1080p (smaller downloads)"
        case .qhd1440: "1440p"
        case .uhd4K: "4K (best quality)"
        }
    }
}

/// Everything the user chooses. Decoding tolerates missing or unknown values
/// so settings saved by an older version never reset the app.
public struct AppSettings: Codable, Equatable, Sendable {
    public var hasCompletedOnboarding = false
    public var selectedInterestIDs: [String] = []
    public var customInterests: [Interest] = []
    public var kindPreference: KindPreference = .both
    public var enabledSources: Set<SourceID> = [.reddit, .wallhaven, .pexels, .bing]
    public var autoChange: AutoChangeInterval = .off
    public var autoChangeKind: MediaKind = .photo
    public var lastAutoChange: Date? = nil
    public var pauseVideoOnBattery = true
    public var pauseVideoWhenCovered = true
    public var videoQuality: VideoQuality = .uhd4K
    public var lockScreenVideoEnabled = false
    public var showLibraryOnLaunch = true
    public var activeLiveWallpaper: Wallpaper? = nil

    public init() {}

    enum CodingKeys: String, CodingKey {
        case hasCompletedOnboarding, selectedInterestIDs, customInterests, kindPreference, enabledSources
        case autoChange, autoChangeKind, lastAutoChange, pauseVideoOnBattery, pauseVideoWhenCovered
        case videoQuality, lockScreenVideoEnabled, showLibraryOnLaunch, activeLiveWallpaper
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = AppSettings()
        func value<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T {
            ((try? container.decodeIfPresent(T.self, forKey: key)) ?? nil) ?? fallback
        }
        hasCompletedOnboarding = value(.hasCompletedOnboarding, defaults.hasCompletedOnboarding)
        selectedInterestIDs = value(.selectedInterestIDs, defaults.selectedInterestIDs)
        customInterests = value(.customInterests, defaults.customInterests)
        kindPreference = value(.kindPreference, defaults.kindPreference)
        enabledSources = value(.enabledSources, defaults.enabledSources)
        autoChange = value(.autoChange, defaults.autoChange)
        autoChangeKind = value(.autoChangeKind, defaults.autoChangeKind)
        lastAutoChange = (try? container.decodeIfPresent(Date.self, forKey: .lastAutoChange)) ?? nil
        pauseVideoOnBattery = value(.pauseVideoOnBattery, defaults.pauseVideoOnBattery)
        pauseVideoWhenCovered = value(.pauseVideoWhenCovered, defaults.pauseVideoWhenCovered)
        videoQuality = value(.videoQuality, defaults.videoQuality)
        lockScreenVideoEnabled = value(.lockScreenVideoEnabled, defaults.lockScreenVideoEnabled)
        showLibraryOnLaunch = value(.showLibraryOnLaunch, defaults.showLibraryOnLaunch)
        activeLiveWallpaper = (try? container.decodeIfPresent(Wallpaper.self, forKey: .activeLiveWallpaper)) ?? nil
    }

    // MARK: - Interests

    /// Selected interests in the order they were picked; unknown ids are skipped.
    public var selectedInterests: [Interest] {
        selectedInterestIDs.compactMap { id in
            InterestCatalog.preset(id: id) ?? customInterests.first { $0.id == id }
        }
    }

    public func isSelected(_ interest: Interest) -> Bool {
        selectedInterestIDs.contains(interest.id)
    }

    public mutating func toggleInterest(_ interest: Interest) {
        if let index = selectedInterestIDs.firstIndex(of: interest.id) {
            selectedInterestIDs.remove(at: index)
            return
        }
        if interest.isCustom, !customInterests.contains(where: { $0.id == interest.id }) {
            customInterests.append(interest)
        }
        selectedInterestIDs.append(interest.id)
    }

    /// Adds and selects an interest the user typed. Returns nil for blank text.
    @discardableResult
    public mutating func addCustomInterest(named name: String) -> Interest? {
        guard let interest = Interest.custom(named: name) else { return nil }
        if !customInterests.contains(where: { $0.id == interest.id }) {
            customInterests.append(interest)
        }
        if !selectedInterestIDs.contains(interest.id) {
            selectedInterestIDs.append(interest.id)
        }
        return customInterests.first { $0.id == interest.id } ?? interest
    }

    public mutating func removeCustomInterest(id: String) {
        customInterests.removeAll { $0.id == id }
        selectedInterestIDs.removeAll { $0 == id }
    }
}

/// Saves settings as JSON in UserDefaults.
public final class SettingsStore {
    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String = "AppSettings.v1") {
        self.defaults = defaults
        self.key = key
    }

    public func load() -> AppSettings {
        guard let data = defaults.data(forKey: key),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return AppSettings()
        }
        return settings
    }

    public func save(_ settings: AppSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: key)
    }
}
