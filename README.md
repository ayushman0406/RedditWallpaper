# Reddit Wallpaper for macOS

A menu bar app that finds wallpapers for the things you love — football, cars, surfing, bikes, superheroes, One Piece, or anything you type — and sets them with one click. Photos and live (video) wallpapers, from several sources, with a full Library window when you want to browse.

## What it does

- **Interests first.** On first launch you pick what you're into (14 presets plus your own, like "Porsche 911" or "Real Madrid"). Change them anytime in Settings or from the Library sidebar.
- **Menu bar popover.** A fresh mix from your interests. Filter by interest, switch between Photos and Live, shuffle, or set one with a click.
- **Library window.** Open it from the popover, by launching the app again, or with ⇧⌘L. Browse For You, Today on Bing, Reddit Picks, each interest, Favorites, History and My Videos. Sort by Top, New or Random, search everything, and open any wallpaper for a big preview and credits.
- **Live wallpapers.** Looping videos play behind your desktop icons on every screen. They're always muted, never keep your Mac awake, and pause when the screen is off or locked. They can also pause on battery and when windows cover the desktop.
- **Your own videos.** Import .mp4/.mov files (for example car loops from MotionBGs) and use them as live wallpapers.
- **Auto-change.** Every 15 minutes, hour, 3 hours or day, from your interests. A change that was due while the Mac slept happens on wake.
- **Lock screen.** See below.
- **Favorites, history and hide.** Heart what you like; hide what you never want to see again.

## Where wallpapers come from

| Source | What it's good for | Setup |
|---|---|---|
| [Wallhaven](https://wallhaven.cc) | High-resolution art, anime (One Piece), superheroes, cars | None (safe-for-work only) |
| Reddit, via [meme-api.com](https://meme-api.com) | Popular posts from wallpaper subreddits | None |
| [Bing](https://www.bing.com) | Photo of the day in 4K | None |
| [Pexels](https://www.pexels.com) | Real photos and **4K videos** of cars, surfing, football, bikes… | Free API key |

Every wallpaper shows its source and author and links to the original page. Photos and videos belong to their creators. Pexels content is free to use with credit; the rest is shared by its uploaders, so treat it as personal wallpaper only.

Reddit closed its free API to new apps in 2026. This app reaches Reddit through meme-api.com, so if that service goes down, the other sources keep working.

### Getting a Pexels key

1. Sign in at [pexels.com/api](https://www.pexels.com/api/) and copy your key (it's free and instant).
2. Paste it in onboarding, or in **Settings → Sources**. It's stored in your keychain.

The free key allows 200 requests per hour, which is plenty for one person.

## Lock screen

| You want | What happens |
|---|---|
| A photo on the lock screen | Set any photo. macOS shows your desktop picture on the lock screen too. |
| A live wallpaper on the lock screen | **Experimental.** Turn on **Settings → Lock Screen → Play live wallpapers on the lock screen and screen saver**, or use **Use on Lock Screen** in a video's preview. |
| A custom startup screen | Not possible. The screen right after power-on (FileVault unlock) loads before your account. |

How the experimental mode works: macOS has no official API for this. The app converts the video to HEVC, adds it to Apple's own aerial wallpaper list in `~/Library/Application Support/com.apple.wallpaper/`, makes it the screen saver, and restarts `WallpaperAgent`. The video shows over the lock screen once the screen saver starts. For that, set **Require password after screen saver begins** to **Immediately** in System Settings → Lock Screen; a hot corner set to **Start Screen Saver** makes it a single move.

- The original settings are backed up first, and **Restore macOS Default** puts them back.
- macOS sometimes resets the choice; the app re-applies it while it runs.
- A macOS update can break it. macOS 27 already changed this area once.
- Quit System Settings while turning it on, because System Settings rewrites these files.

The technique comes from [Mural](https://github.com/da-the-dev/mural) (MIT). See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## Requirements

- macOS 26 (Tahoe) or later
- Xcode 26 or later to build

## Build and run

1. Clone the repository and open `RedditWallpaper.xcodeproj`.
2. Choose the **RedditWallpaper** scheme and press ⌘R.
3. The welcome window opens on first launch; afterwards the app lives in the menu bar.

Notes:

- The App Sandbox is off, because the lock-screen feature writes to Apple's wallpaper settings and restarts `WallpaperAgent`. That also means the app can't go on the Mac App Store.
- With "Sign to Run Locally", every rebuild has a new signature, so macOS may ask once per build to let the app read its Pexels key from the keychain. Click **Always Allow**.

## Project layout

```
Packages/WallpaperCore/   Logic with unit tests: sources, interests, feed mixing,
                          settings, playback rules, lock-screen file editing
RedditWallpaper/App/      App model, feed paging, windows, app delegate
RedditWallpaper/Services/ Downloads, stills, live wallpaper engine, auto-change,
                          keychain, lock screen
RedditWallpaper/Views/    Menu bar popover, Library, onboarding, settings
```

## Tests and CI

```bash
swift test --package-path Packages/WallpaperCore
```

GitHub Actions (`.github/workflows/ci.yml`) runs the package tests and builds the app on a macOS 26 runner for every push.

## Sharing it on your website

To let other people download it without security warnings:

1. Join the Apple Developer Program and sign with a **Developer ID Application** certificate (Hardened Runtime is already on).
2. Notarize the app with `xcrun notarytool` and staple the ticket.
3. Ship it as a DMG. [Sparkle](https://sparkle-project.org) is the usual way to add auto-updates.
4. Let each user add their own Pexels key (as now), or put a small proxy in front of Pexels. A key built into the app would be shared by everyone and hit the rate limit quickly.

## Built with

Swift, SwiftUI, AppKit and AVFoundation. No third-party dependencies.
