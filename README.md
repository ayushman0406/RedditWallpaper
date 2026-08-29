# Reddit Wallpaper for macOS 🖼️

A native, lightweight macOS Menu Bar app that fetches the top wallpapers of the week from `r/wallpaper` on Reddit and lets you set them as your desktop background with a single click.

## Features ✨
- **Unobtrusive Menu Bar App**: Lives entirely in your Mac's top status bar. No messy Dock icons.
- **Live Previews**: Fetches 10 fresh, highly-rated wallpapers from Reddit and shows beautiful thumbnails directly in the menu.
- **Smart Storage**: Uses low-memory thumbnails for previews and only downloads the massive 4K full-resolution files when you explicitly choose to apply them.
- **NSFW Filter**: Automatically skips any NSFW-tagged posts to keep your desktop safe for work.
- **Multi-Monitor Support**: Automatically applies your chosen wallpaper to all connected displays simultaneously.

## Requirements 💻
- macOS 13.0 or newer
- Xcode 14 or newer (for building the app)

## How to Install & Run 🚀

### Option 1: Running via Xcode (For Developers)
1. Clone this repository to your Mac:
   ```bash
   git clone https://github.com/ayushman0406/RedditWallpaper.git
   ```
2. Open the `RedditWallpaper.xcodeproj` file in Xcode.
3. Select your Mac as the build destination.
4. Press `Cmd + R` or click the Play button to Build and Run.
5. The photo icon will appear in your top menu bar!

### Option 2: Exporting as a Standalone App (For Daily Use)
If you want to install it permanently in your `Applications` folder so it runs without Xcode:
1. Open the project in Xcode.
2. In the top menu bar, click **Product** > **Archive**.
3. When the Organizer window opens, click **Distribute App**.
4. Select **Custom** > **Copy App**.
5. Choose your `Applications` folder as the destination.
6. You can now launch "RedditWallpaper" from Launchpad or Spotlight anytime!

## Built With 🛠️
- **Swift & SwiftUI**: 100% native macOS UI.
- **AppKit**: Utilizes classic `NSStatusItem` and `NSPopover` for bulletproof menu bar rendering.
- **Meme-API**: Bypasses strict Reddit rate limits to fetch reliable JSON data.
