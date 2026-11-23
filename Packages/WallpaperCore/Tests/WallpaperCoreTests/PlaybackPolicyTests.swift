import Testing
@testable import WallpaperCore

@Suite struct PlaybackPolicyTests {
    let pauseBoth = PlaybackPreferences(pauseOnBattery: true, pauseWhenCovered: true)
    let pauseNeither = PlaybackPreferences(pauseOnBattery: false, pauseWhenCovered: false)

    @Test func playsWhenAllClear() {
        #expect(PlaybackPolicy.shouldPlay(PlaybackConditions(), pauseBoth))
    }

    @Test func pausesWhenAsleepLockedInactiveOrUserPaused() {
        #expect(!PlaybackPolicy.shouldPlay(PlaybackConditions(screensAsleep: true), pauseNeither))
        #expect(!PlaybackPolicy.shouldPlay(PlaybackConditions(screenLocked: true), pauseNeither))
        #expect(!PlaybackPolicy.shouldPlay(PlaybackConditions(sessionActive: false), pauseNeither))
        #expect(!PlaybackPolicy.shouldPlay(PlaybackConditions(userPaused: true), pauseNeither))
    }

    @Test func batteryPausesOnlyWhenPreferred() {
        let onBattery = PlaybackConditions(onBattery: true)
        #expect(!PlaybackPolicy.shouldPlay(onBattery, pauseBoth))
        #expect(PlaybackPolicy.shouldPlay(onBattery, pauseNeither))
    }

    @Test func coveredPausesOnlyWhenPreferred() {
        let covered = PlaybackConditions(desktopVisible: false)
        #expect(!PlaybackPolicy.shouldPlay(covered, pauseBoth))
        #expect(PlaybackPolicy.shouldPlay(covered, pauseNeither))
    }
}
