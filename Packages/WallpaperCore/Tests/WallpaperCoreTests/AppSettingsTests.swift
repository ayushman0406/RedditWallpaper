import Foundation
import Testing
@testable import WallpaperCore

@Suite struct AppSettingsTests {
    @Test func decodesEmptyJSONToDefaults() throws {
        let settings = try JSONDecoder().decode(AppSettings.self, from: Data("{}".utf8))
        #expect(settings == AppSettings())
        #expect(!settings.hasCompletedOnboarding)
        #expect(settings.kindPreference == .both)
        #expect(settings.enabledSources == [.reddit, .wallhaven, .pexels, .bing])
        #expect(settings.autoChange == .off)
        #expect(settings.videoQuality == .uhd4K)
        #expect(settings.pauseVideoOnBattery)
        #expect(settings.pauseVideoWhenCovered)
        #expect(!settings.lockScreenVideoEnabled)
        #expect(settings.showLibraryOnLaunch)
        #expect(settings.activeLiveWallpaper == nil)
    }

    @Test func decodesPartialJSONKeepingDefaults() throws {
        let json = #"{"hasCompletedOnboarding":true,"selectedInterestIDs":["cars"]}"#
        let settings = try JSONDecoder().decode(AppSettings.self, from: Data(json.utf8))
        #expect(settings.hasCompletedOnboarding)
        #expect(settings.selectedInterestIDs == ["cars"])
        #expect(settings.pauseVideoWhenCovered)
        #expect(settings.showLibraryOnLaunch)
        #expect(settings.kindPreference == .both)
    }

    @Test func unknownValuesFallBackToDefaults() throws {
        let json = #"{"autoChange":"everyMinute","hasCompletedOnboarding":true}"#
        let settings = try JSONDecoder().decode(AppSettings.self, from: Data(json.utf8))
        #expect(settings.autoChange == .off)
        #expect(settings.hasCompletedOnboarding)
    }

    @Test func roundTripsThroughStore() throws {
        let suite = "WallpaperCoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = SettingsStore(defaults: defaults)
        #expect(store.load() == AppSettings())

        var settings = AppSettings()
        settings.hasCompletedOnboarding = true
        settings.selectedInterestIDs = ["onePiece", "cars"]
        settings.autoChange = .hourly
        settings.lastAutoChange = Date(timeIntervalSince1970: 1_700_000_000)
        settings.activeLiveWallpaper = wallpaper("live")
        store.save(settings)
        #expect(SettingsStore(defaults: defaults).load() == settings)
    }

    @Test func selectedInterestsKeepOrderSkipUnknownIncludeCustom() throws {
        var settings = AppSettings()
        let custom = try #require(Interest.custom(named: "Real Madrid"))
        settings.customInterests = [custom]
        settings.selectedInterestIDs = ["onePiece", "gone", custom.id, "cars"]
        #expect(settings.selectedInterests.map(\.id) == ["onePiece", custom.id, "cars"])
    }

    @Test func toggleInterestAddsThenRemoves() {
        var settings = AppSettings()
        let cars = InterestCatalog.preset(id: "cars")!
        settings.toggleInterest(cars)
        #expect(settings.isSelected(cars))
        #expect(settings.selectedInterestIDs == ["cars"])
        settings.toggleInterest(cars)
        #expect(!settings.isSelected(cars))
        #expect(settings.selectedInterestIDs.isEmpty)
    }

    // Mutating calls happen outside #expect/#require: the macros can't call
    // mutating members.
    @Test func addCustomInterestSelectsAndDedupes() throws {
        var settings = AppSettings()
        let first = settings.addCustomInterest(named: "Real Madrid")
        let added = try #require(first)
        #expect(settings.isSelected(added))
        let again = settings.addCustomInterest(named: "real madrid")
        #expect(again?.id == added.id)
        #expect(settings.customInterests.count == 1)
        #expect(settings.selectedInterestIDs == [added.id])
        let blank = settings.addCustomInterest(named: "  ")
        #expect(blank == nil)
    }

    @Test func removeCustomInterestDeselects() throws {
        var settings = AppSettings()
        let first = settings.addCustomInterest(named: "Porsche 911")
        let added = try #require(first)
        settings.removeCustomInterest(id: added.id)
        #expect(settings.customInterests.isEmpty)
        #expect(settings.selectedInterestIDs.isEmpty)
    }

    @Test func autoChangeIsDue() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        #expect(!AutoChangeInterval.off.isDue(lastChange: nil, now: now))
        #expect(AutoChangeInterval.hourly.isDue(lastChange: nil, now: now))
        #expect(!AutoChangeInterval.hourly.isDue(lastChange: now.addingTimeInterval(-59 * 60), now: now))
        #expect(AutoChangeInterval.hourly.isDue(lastChange: now.addingTimeInterval(-60 * 60), now: now))
        #expect(AutoChangeInterval.daily.seconds == 86_400)
        #expect(AutoChangeInterval.off.seconds == nil)
    }
}
