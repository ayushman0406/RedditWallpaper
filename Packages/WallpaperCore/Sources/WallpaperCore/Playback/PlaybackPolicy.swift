import Foundation

/// What the Mac is doing right now, as far as a live wallpaper cares.
public struct PlaybackConditions: Equatable, Sendable {
    public var screensAsleep: Bool
    public var screenLocked: Bool
    public var sessionActive: Bool
    public var onBattery: Bool
    public var desktopVisible: Bool
    public var userPaused: Bool

    public init(
        screensAsleep: Bool = false,
        screenLocked: Bool = false,
        sessionActive: Bool = true,
        onBattery: Bool = false,
        desktopVisible: Bool = true,
        userPaused: Bool = false
    ) {
        self.screensAsleep = screensAsleep
        self.screenLocked = screenLocked
        self.sessionActive = sessionActive
        self.onBattery = onBattery
        self.desktopVisible = desktopVisible
        self.userPaused = userPaused
    }
}

public struct PlaybackPreferences: Equatable, Sendable {
    public var pauseOnBattery: Bool
    public var pauseWhenCovered: Bool

    public init(pauseOnBattery: Bool = true, pauseWhenCovered: Bool = true) {
        self.pauseOnBattery = pauseOnBattery
        self.pauseWhenCovered = pauseWhenCovered
    }
}

public enum PlaybackPolicy {
    /// A live wallpaper only plays when someone can see it and the user's
    /// battery and coverage preferences allow it.
    public static func shouldPlay(_ conditions: PlaybackConditions, _ preferences: PlaybackPreferences) -> Bool {
        if conditions.screensAsleep || conditions.screenLocked || !conditions.sessionActive || conditions.userPaused {
            return false
        }
        if preferences.pauseOnBattery, conditions.onBattery { return false }
        if preferences.pauseWhenCovered, !conditions.desktopVisible { return false }
        return true
    }
}
