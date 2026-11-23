# Interests, Library Window & Live Wallpapers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the single-feed Reddit menu bar app into an interest-driven wallpaper app: onboarding interest picker (editable later), many sources, the existing menu bar popover plus a full Library window, live (video) desktop wallpapers, and an experimental lock-screen/screen-saver video mode.

**Architecture:** All decision-making logic (sources, request building, response parsing, feed mixing, settings, playback policy, lock-screen store editing) lives in a local Swift package `Packages/WallpaperCore` with unit tests that CI runs on a macOS runner. The app target (SwiftUI + AppKit) is a thin layer: an `@Observable` `AppModel`, an AppKit `WindowCoordinator` for the Library/Settings/Onboarding windows, the existing `NSStatusItem` popover, and AppKit/AVFoundation services for applying stills, playing videos behind the desktop icons, and writing to Apple's wallpaper store.

**Tech Stack:** Swift 6.2 toolchain (Xcode 26), SwiftUI, AppKit, AVFoundation, IOKit (power source), ServiceManagement (launch at login), Security (Keychain), Swift Testing, GitHub Actions `macos-26`.

**Spec:** No separate spec. The user opted out of the design review ("just implement it, I'll see after"). Requirements come from the conversation and are copied into Global Constraints below.

## Global Constraints

- Keep the menu bar icon + popover as the primary quick UI; add a full Library window opened from the popover, on manual launch, and on reopen.
- First launch shows onboarding: pick interests (presets must include Football, Cars, Surfing, Motorbikes, Bicycles, Superheroes, One Piece) plus custom interests; choose Photos / Live; optional Pexels key. Interests are editable later in Settings and from the Library sidebar.
- Sources: Reddit via `https://meme-api.com/gimme/{subreddit}/{count}`, Wallhaven `https://wallhaven.cc/api/v1/search`, Pexels photos `https://api.pexels.com/v1/search` + `/v1/curated`, Pexels videos `https://api.pexels.com/v1/videos/search` + `/v1/videos/popular` (header `Authorization: <key>`), Bing `https://www.bing.com/HPImageArchive.aspx?format=js&idx=0&n=8&mkt=en-US`.
- Only safe-for-work content: Reddit `nsfw`/`spoiler` posts dropped; Wallhaven `purity=100` and items with `purity != "sfw"` dropped.
- Desktop-sized results only: items with known size must be landscape (width/height ≥ 1.2) and at least 1920×1080; unknown size is kept.
- Pexels key is optional and stored in the Keychain (service `com.kayushman.RedditWallpaper`, account `pexels-api-key`), never in UserDefaults.
- Credit sources: every card/detail shows source name and author when known, and links to the source page.
- Live wallpapers never keep the display awake, always muted, pause when screens sleep/lock, and (by default) pause on battery and when the desktop is covered.
- Lock screen: stills set on the desktop also appear on the lock screen (macOS mirrors them). Lock-screen/screen-saver video is opt-in, labeled Experimental, backs up `Index.plist` and the aerial manifest before the first write, and offers Restore.
- Project: deployment target macOS 26.0, App Sandbox off (lock-screen feature writes outside the container and restarts `WallpaperAgent`), Hardened Runtime on, bundle id unchanged `com.kayushman.RedditWallpaper`.
- App code compiles with the project's existing settings: Swift 5 mode, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, `MemberImportVisibility` on (every file imports each module whose members it uses).
- Package: `swift-tools-version: 6.0`, `swiftLanguageModes: [.v5]`, platforms `.macOS(.v14)`, no third-party dependencies.

## Review Focus

1. Custom interests containing `&`, `+`, `#` or spaces ("Tom & Jerry", "C++") must still produce valid requests: values are percent-encoded so `&` → `%26`, `+` → `%2B`, space → `%20`. (Task 2 `QueryStringTests`, Task 3 Wallhaven test with `"Tom & Jerry"`.)
2. No network / every source failing must end loading with a visible message, not an endless spinner or blank list. (Task 4 `allSourcesFailingReturnsErrorsAndNoItems`; app shows `FeedPage.errors`.)
3. Settings written by an older build (missing keys) must still load with defaults instead of resetting onboarding. (Task 5 `decodesPartialJSONKeepingDefaults`.)
4. A live wallpaper must stop draining battery when the lid closes, the screen locks or the Mac runs on battery. (Task 5 `PlaybackPolicyTests`; app wires all notifications into the policy.)
5. Unplugging/plugging a monitor while a live wallpaper plays must not leave a frozen or missing window. (Task 8 rebuilds windows on `didChangeScreenParametersNotification`.)

---

## File Structure

```
Packages/WallpaperCore/
  Package.swift
  Sources/WallpaperCore/
    Models/Wallpaper.swift            MediaKind, SourceID, Wallpaper
    Models/Interest.swift             Interest, InterestCatalog
    Util/ResolutionParser.swift       "[3840x2160]" parsing + title cleanup
    Util/QueryString.swift            strict query encoding
    Util/SeededRandom.swift           FNV-1a seed + SplitMix64 shuffle
    Sources/WallpaperSource.swift     SortOrder, SourceQuery, WallpaperSource, SourceError
    Sources/RedditSource.swift
    Sources/WallhavenSource.swift
    Sources/PexelsSource.swift
    Sources/BingDailySource.swift
    Feed/HTTPClient.swift             HTTPClient, URLSessionHTTPClient
    Feed/FeedService.swift            FeedRequest, FeedPage, FeedService
    Settings/AppSettings.swift        AppSettings, KindPreference, AutoChangeInterval, VideoQuality, SettingsStore
    Settings/LibraryState.swift       LibraryState, LibraryFileStore
    Playback/PlaybackPolicy.swift     PlaybackConditions, PlaybackPreferences, PlaybackPolicy
    LockScreen/WallpaperStoreEditor.swift
    LockScreen/AerialManifestEditor.swift
  Tests/WallpaperCoreTests/
    Fixtures/{memeapi-wallpaper,memeapi-error,wallhaven-onepiece,pexels-photos,pexels-videos,bing}.json
    FixtureLoader.swift + one *Tests.swift per source file above
.github/workflows/ci.yml
RedditWallpaper.xcodeproj/project.pbxproj                (package ref, sandbox off, 26.0, hardened runtime)
RedditWallpaper.xcodeproj/xcshareddata/xcschemes/RedditWallpaper.xcscheme
RedditWallpaper/
  RedditWallpaperApp.swift            @main + AppDelegate adaptor (rewritten)
  App/AppDelegate.swift               status item, popover, launch/reopen flow
  App/AppModel.swift                  @Observable state + actions
  App/FeedController.swift            @Observable paging for one collection
  App/LibraryCollection.swift         sidebar collections → FeedRequest
  App/WindowCoordinator.swift         Library / Settings / Onboarding windows
  Services/KeychainStore.swift
  Services/DownloadCache.swift
  Services/WallpaperApplier.swift     stills via NSWorkspace
  Services/VideoWallpaperController.swift (+ VideoWallpaperWindow)
  Services/PowerSourceMonitor.swift
  Services/AutoChanger.swift
  Services/LaunchAtLogin.swift
  Services/VideoTranscoder.swift
  Services/LockScreenService.swift
  Views/Shared/{SymbolImage,ThumbnailView,InterestPicker,SourceBadge}.swift
  Views/MenuBar/MenuBarView.swift     replaces ContentView.swift
  Views/Library/{LibraryView,WallpaperGrid,WallpaperCard,WallpaperDetailView}.swift
  Views/Onboarding/OnboardingView.swift
  Views/Settings/SettingsView.swift
Deleted: ContentView.swift, WallpaperManager.swift, RedditFetcher.swift, DesktopManager.swift
```

Verification for every task: push the branch and read the `CI` workflow run (jobs `core-tests` and `app-build`) with the GitHub MCP actions tools. Neither this container nor a Mac is available locally.

---

### Task 1: Package scaffold, project wiring, CI

**Files:**
- Create: `Packages/WallpaperCore/Package.swift`, `Sources/WallpaperCore/Util/ResolutionParser.swift`, `Tests/WallpaperCoreTests/ResolutionParserTests.swift`
- Create: `.github/workflows/ci.yml`, `.gitignore`, `RedditWallpaper.xcodeproj/xcshareddata/xcschemes/RedditWallpaper.xcscheme`
- Modify: `RedditWallpaper.xcodeproj/project.pbxproj`

**Interfaces:**
- Produces: library product `WallpaperCore`; `ResolutionParser.resolution(in title: String) -> (width: Int, height: Int)?`, `ResolutionParser.cleanTitle(_ title: String) -> String`.

- [ ] **Step 1: Write failing tests** `ResolutionParserTests`:
  - `parsesBracketedResolution`: `"Vestrahorn [3840x2160]"` → `(3840, 2160)`
  - `parsesSpacedAndUnicodeTimes`: `"Lake Bled (2560 × 1440)"` → `(2560, 1440)`
  - `returnsNilWithoutResolution`: `"My cat"` → `nil`
  - `cleanTitleStripsResolutionAndOC`: `"[OC] Sunset at Big Sur [5000x3000]"` → `"Sunset at Big Sur"`
- [ ] **Step 2: Wire the package into the app project** in `project.pbxproj`: `XCLocalSwiftPackageReference` (relativePath `Packages/WallpaperCore`), `XCSwiftPackageProductDependency` (`WallpaperCore`), a `PBXBuildFile` in the Frameworks phase, `packageProductDependencies` on the target, `packageReferences` on the project. Set `MACOSX_DEPLOYMENT_TARGET = 26.0` (both project configs), `ENABLE_APP_SANDBOX = NO`, `ENABLE_HARDENED_RUNTIME = YES` (both target configs). Add a shared scheme for target `A922D24430434950008C5FE6`.
- [ ] **Step 3: CI** `ci.yml` on push/PR/dispatch, `runs-on: macos-26`; job `core-tests`: `swift test --package-path Packages/WallpaperCore`; job `app-build`: `xcodebuild -project RedditWallpaper.xcodeproj -scheme RedditWallpaper -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build` with `set -o pipefail`. Both print `xcodebuild -version` first.
- [ ] **Step 4: Push with tests only (parser stubbed to return nil/input)**; expected: `core-tests` FAIL on the 3 parser assertions, `app-build` PASS (proves wiring).
- [ ] **Step 5: Implement the parser** (regex `(\d{3,5})\s*[x×X]\s*(\d{3,5})` inside `[]` or `()`, also bare); push; expected both jobs PASS.
- [ ] **Step 6: Commit** `build: add WallpaperCore package, CI, project settings`.

### Task 2: Core models and utilities

**Files:**
- Create: `Models/Wallpaper.swift`, `Models/Interest.swift`, `Util/QueryString.swift`, `Util/SeededRandom.swift`
- Test: `WallpaperTests.swift`, `InterestTests.swift`, `QueryStringTests.swift`, `SeededRandomTests.swift`

**Interfaces:**
- Produces:
  - `enum MediaKind: String, Codable, Sendable, CaseIterable { case photo, video }`
  - `enum SourceID: String, Codable, Sendable, CaseIterable { case reddit, wallhaven, pexels, bing, local; var displayName: String }`
  - `struct Wallpaper: Codable, Hashable, Sendable, Identifiable` with `id: String` (`"<source>:<nativeID>"`), `source`, `kind`, `title`, `author: String?`, `thumbnailURL: URL`, `mediaURL: URL`, `pageURL: URL?`, `width: Int?`, `height: Int?`, `score: Int?`, `createdAt: Date?`, `duration: Double?`, `interestIDs: [String]`; computed `aspectRatio: Double?`, `resolutionLabel: String?` (`"3840 × 2160"`), `qualityBadge: String?` (≥7680 "8K", ≥5120 "5K", ≥3840 "4K", ≥2560 "QHD", ≥1920 "HD"), `preferredFileExtension: String`.
  - `struct Interest: Codable, Hashable, Sendable, Identifiable` with `id, name, symbol, searchTerms: [String], wallhavenCategories: String, subreddits: [String], isCustom: Bool`; `static func custom(named: String) -> Interest?`; `func searchTerm(forPage: Int) -> String?`; `func sourcePage(forPage: Int) -> Int`.
  - `enum InterestCatalog { static let presets: [Interest]; static func preset(id: String) -> Interest?; static let redditPicksSubreddits = ["wallpaper", "wallpapers", "WidescreenWallpaper"] }`
  - `enum QueryString { static func encode(_ items: [(String, String)]) -> String }`
  - `struct SeededGenerator: RandomNumberGenerator { init(seed: String) }`, `extension Array { func seededShuffle(seed: String) -> [Element] }`

Preset table (id · name · symbol · searchTerms · wallhavenCategories · subreddits):
football · Football · soccerball · ["soccer", "football stadium", "football"] · 100 · [] —
americanFootball · American Football · football.fill · ["american football", "nfl"] · 100 · [] —
cars · Cars · car.fill · ["sports car", "supercar", "jdm", "car"] · 100 · [] —
surfing · Surfing · figure.surfing · ["surfing", "surfer", "ocean waves"] · 100 · [] —
motorbikes · Motorbikes · motorcycle · ["motorcycle", "superbike"] · 100 · [] —
bicycles · Bicycles · bicycle · ["cycling", "mountain bike", "bicycle"] · 100 · [] —
superheroes · Superheroes · bolt.shield.fill · ["superhero", "marvel", "dc comics", "spider-man", "batman"] · 111 · [] —
onePiece · One Piece · sailboat.fill · ["one piece", "monkey d. luffy", "roronoa zoro"] · 110 · [] —
anime · Anime · sparkles · ["anime", "anime landscape"] · 010 · ["Animewallpaper"] —
nature · Nature · leaf.fill · ["nature", "landscape", "forest"] · 100 · ["EarthPorn"] —
space · Space · moon.stars.fill · ["space", "galaxy", "nebula"] · 100 · ["spaceporn"] —
cities · Cities · building.2.fill · ["city", "skyline", "cityscape"] · 100 · ["CityPorn"] —
gaming · Gaming · gamecontroller.fill · ["video games", "gaming"] · 111 · [] —
minimal · Minimal · circle.lefthalf.filled · ["minimalism", "minimalist"] · 100 · ["MinimalWallpaper"]

- [ ] **Step 1: Failing tests**
  - `WallpaperTests`: `aspectRatioAndBadge` (3840×2160 → ratio≈1.778, badge "4K", label "3840 × 2160"); `fileExtensionFromURLOrKindDefault` (`…/a.PNG` → "png"; photo `…/th?id=x` → "jpg"; video no ext → "mp4"); `codableRoundTrip`.
  - `InterestTests`: `presetsIncludeUserInterests` (ids football, cars, surfing, motorbikes, bicycles, superheroes, onePiece present); `presetIDsAreUnique`; `everyPresetHasSearchTerms`; `customInterestSlug` (`"  Real Madrid "` → id `"custom:real-madrid"`, name `"Real Madrid"`, searchTerms `["Real Madrid"]`, categories `"111"`, isCustom true); `customInterestRejectsBlank` (`"   "` → nil); `searchTermRotation` (terms [a,b,c]: page1 a/p1, page2 b/p1, page4 a/p2).
  - `QueryStringTests`: `encodesReservedCharacters` (`[("q","Tom & Jerry"),("x","C++")]` → `"q=Tom%20%26%20Jerry&x=C%2B%2B"`); `keepsUnreservedCharacters` (`("a","one-piece_1.0~")` unchanged).
  - `SeededRandomTests`: `sameSeedSameOrder`; `differentSeedDifferentOrder` (array 0..<20).
- [ ] **Step 2: Run** `swift test --package-path Packages/WallpaperCore` via CI; expected FAIL (symbols missing → compile error counts as red).
- [ ] **Step 3: Implement** the types above. `QueryString` allows only `A–Z a–z 0–9 - . _ ~` unescaped. FNV-1a 64-bit of the UTF-8 seed feeds SplitMix64.
- [ ] **Step 4: Run tests**; expected PASS.
- [ ] **Step 5: Commit** `feat(core): wallpaper and interest models`.

### Task 3: Sources

**Files:**
- Create: `Sources/WallpaperSource.swift`, `RedditSource.swift`, `WallhavenSource.swift`, `PexelsSource.swift`, `BingDailySource.swift`
- Create fixtures (real captures for meme-api, Wallhaven, Bing; Pexels from its documented schema incl. an `hls` file with null width)
- Test: one test file per source + `FixtureLoader.swift` (`Bundle.module`, `resources: [.copy("Fixtures")]`)

**Interfaces:**
- Consumes: Task 2 types.
- Produces:
  - `enum SortOrder: String, Codable, Sendable, CaseIterable { case top, new, random; var displayName: String }`
  - `struct SourceQuery: Sendable, Hashable { enum Scope: Sendable, Hashable { case general, interest(Interest), search(String) }; var scope; var kind: MediaKind; var sort: SortOrder; var page: Int; var minWidth: Int; var minHeight: Int; var seed: String; var interestID: String? }` (defaults page 1, 1920, 1080, seed "w4llp4")
  - `protocol WallpaperSource: Sendable { var id: SourceID { get }; func supports(_:) -> Bool; func makeRequest(for:) throws -> URLRequest; func parse(_ data: Data, for: SourceQuery) throws -> [Wallpaper]; func errorMessage(status: Int, data: Data) -> String }` (default `errorMessage`: 401/403 "The API key was rejected.", 429 "Rate limit reached. Try again in a few minutes.", else `"HTTP <status>"` + JSON `message` if present)
  - `enum SourceError: Error, Equatable, Sendable { case badStatus(SourceID, Int, String), decoding(SourceID, String), transport(SourceID, String); var source: SourceID; var message: String }`
  - `struct RedditSource: WallpaperSource { init(count: Int = 30) }`, `struct WallhavenSource: WallpaperSource { init() }`, `struct PexelsSource: WallpaperSource { init(apiKey: String?, maxVideoWidth: Int = 3840); static func bestVideoFile(_ files: [VideoFile], maxWidth: Int) -> VideoFile?; static func title(fromPageURL: URL) -> String? }`, `struct BingDailySource: WallpaperSource { init(market: String = "en-US") }`

Rules:
- Reddit: supports `.photo` + scope `.general` (picks subreddits) or `.interest` with non-empty `subreddits`; subreddit = list[(page-1) % count]; parse drops nsfw/spoiler/non `jpg|jpeg|png` URLs; thumbnail = preview containing `width=640`, else last preview, else url; size from title; title cleaned; id `reddit:<postLink last path component>`; `top` sorts by `ups` desc; author `u/<author>`.
- Wallhaven: supports `.photo` and every scope; q = search text, interest term for page, or empty; `categories` = interest's or `111`; `purity=100`; sorting `top`→`favorites` when q non-empty else `toplist`+`topRange=1M`; `new`→`date_added`; `random`→`random`+`seed` (seed must be 6 alphanumerics; derive from query seed); `atleast=<minW>x<minH>`; `page` = `sourcePage`; parse drops `purity != sfw`; id `wallhaven:<id>`; title `"<Interest name or Wallhaven> wallpaper"`; thumbnail `thumbs.large`; media `path`; score `favorites`; date `yyyy-MM-dd HH:mm:ss` UTC.
- Pexels: supports both kinds only when key non-empty; photos `/v1/search?query=&orientation=landscape&size=medium&per_page=30&page=` or `/v1/curated?per_page=30&page=` for `.general`; videos `/v1/videos/search?query=&orientation=landscape&size=medium&per_page=20&page=` or `/v1/videos/popular?min_width=1920&per_page=20&page=`; header `Authorization`; photo media `src.original`, thumb `src.medium`, author photographer, title `alt` or `"Photo by <name>"`; video media = `bestVideoFile` (mp4, non-nil width, quality ≠ hls, largest width ≤ max else smallest), thumb `image`, title from URL slug (`/video/aerial-view-of-surfers-1234/` → "Aerial view of surfers") else `"Video by <user>"`, duration; ids `pexels:photo-<id>` / `pexels:video-<id>`.
- Bing: supports `.photo` + `.general` only; media `https://www.bing.com<urlbase>_UHD.jpg`, thumb `…_800x480.jpg`, id `bing:<startdate>`, author = `copyright`, page = `copyrightlink`, width 3840 height 2160, date from `startdate` (`yyyyMMdd`).

- [ ] **Step 1: Failing tests** (names → key assertions):
  - Reddit: `requestUsesInterestSubreddit` (anime p1 → `https://meme-api.com/gimme/Animewallpaper/30`); `requestUsesPicksForGeneral` (p2 → `/gimme/wallpapers/30`); `unsupportedForVideoAndOffTopicInterest` (cars → false); `parsesFixture` (3 posts; ids, thumbnail has `width=640`, title `"Vestrahorn"`, size 3840×2160, score 273); `dropsNSFWAndNonImages`; `topSortsByUpvotes`; `errorMessageReadsMemeAPIMessage` (400 fixture → `"r/carporn has no Posts with Images"`).
  - Wallhaven: `topRequestForInterest` (onePiece p1 → path `/api/v1/search`, items q=one%20piece, categories=110, purity=100, sorting=favorites, atleast=1920x1080, page=1); `generalTopUsesToplist`; `newUsesDateAdded`; `randomIncludesSixCharSeed`; `searchTextIsEncoded` (`"Tom & Jerry"` → `q=Tom%20%26%20Jerry`); `parsesFixture` (first id `wallhaven:72lej9`, media `https://w.wallhaven.cc/full/72/wallhaven-72lej9.png`, 7680×4320, score 847); `dropsNonSFW`.
  - Pexels: `unsupportedWithoutKey`; `photoSearchRequest` (header Authorization == key, query items); `videoSearchUsesV1VideosPath` (`/v1/videos/search`); `generalUsesCuratedAndPopular`; `parsesPhotos`; `parsesVideosPicksBestFile` (max 3840 → the 3840 file; max 1920 → the 1920 file; hls ignored); `titleFromSlug`.
  - Bing: `onlyGeneralPhotos`; `parsesFixture` (3 items, first media `https://www.bing.com/th?id=OHR.FibonacciFern_EN-US6307771770_UHD.jpg`, id `bing:20261123`, title "Geometry in nature").
- [ ] **Step 2: Run tests** (CI); expected FAIL.
- [ ] **Step 3: Implement** the four sources per the rules.
- [ ] **Step 4: Run tests**; expected PASS.
- [ ] **Step 5: Commit** `feat(core): Reddit, Wallhaven, Pexels and Bing sources`.

### Task 4: Feed service

**Files:**
- Create: `Feed/HTTPClient.swift`, `Feed/FeedService.swift`
- Test: `FeedServiceTests.swift` (with `MockHTTPClient` keyed by URL host, and a `StubSource`)

**Interfaces:**
- Consumes: Tasks 2–3.
- Produces:
  - `protocol HTTPClient: Sendable { func data(for: URLRequest) async throws -> (Data, HTTPURLResponse) }`, `struct URLSessionHTTPClient: HTTPClient { init(session: URLSession = .shared) }`
  - `struct FeedRequest: Sendable, Hashable { var scopes: [SourceQuery.Scope]; var kind: MediaKind; var sort: SortOrder; var page: Int; var minWidth: Int; var minHeight: Int; var seed: String; var excludedIDs: Set<String>; var enabledSources: Set<SourceID> }` (defaults page 1, 1920×1080, seed "w4llp4", excluded [], enabled all)
  - `struct FeedPage: Sendable { var items: [Wallpaper]; var errors: [SourceError]; var isExhausted: Bool }`
  - `struct FeedService: Sendable { init(sources: [any WallpaperSource], client: any HTTPClient); func load(_: FeedRequest) async -> FeedPage; static func interleave(_: [[Wallpaper]]) -> [Wallpaper]; static func isSuitable(_: Wallpaper, minWidth: Int, minHeight: Int) -> Bool }`

Algorithm: one query per (scope, enabled supporting source), fetched concurrently, results kept in (scope, source) order → interleave → dedupe by `id` then by `mediaURL` → drop excluded and unsuitable → tag `interestIDs` with the producing interest (merge when duplicates collapse) → `random` sort applies `seededShuffle(seed: "\(seed)-\(page)")`. `isExhausted` = no source returned any item.

- [ ] **Step 1: Failing tests**: `interleavesRoundRobin` ([[a1,a2,a3],[b1]] → a1,b1,a2,a3); `mergesInterestsAndTagsItems` (cars + surfing scopes → items tagged with their interest id); `dedupesByIDAndMediaURL`; `excludesBlockedIDs`; `dropsPortraitAndSmallKnownSizes` (1080×1920 and 1280×720 dropped, unknown kept); `skipsDisabledAndUnsupportedSources` (no request recorded for them); `partialFailureKeepsItemsAndReportsError` (500 from one host → 1 `badStatus` error, other items present); `allSourcesFailingReturnsErrorsAndNoItems` (`isExhausted` true, errors non-empty); `randomSortIsDeterministic`.
- [ ] **Step 2: Run tests**; expected FAIL.
- [ ] **Step 3: Implement**.
- [ ] **Step 4: Run tests**; expected PASS.
- [ ] **Step 5: Commit** `feat(core): feed service mixing sources and interests`.

### Task 5: Settings, library state, playback policy

**Files:**
- Create: `Settings/AppSettings.swift`, `Settings/LibraryState.swift`, `Playback/PlaybackPolicy.swift`
- Test: `AppSettingsTests.swift`, `LibraryStateTests.swift`, `PlaybackPolicyTests.swift`

**Interfaces:**
- Produces:
  - `enum KindPreference: String, Codable, Sendable, CaseIterable { case photos, live, both }`
  - `enum AutoChangeInterval: String, Codable, Sendable, CaseIterable { case off, every15Minutes, hourly, every3Hours, daily; var seconds: TimeInterval?; var displayName: String; func isDue(lastChange: Date?, now: Date) -> Bool }`
  - `enum VideoQuality: Int, Codable, Sendable, CaseIterable { case hd1080 = 1920, qhd1440 = 2560, uhd4K = 3840; var displayName: String }`
  - `struct AppSettings: Codable, Equatable, Sendable` fields + defaults: `hasCompletedOnboarding=false, selectedInterestIDs=[], customInterests=[], kindPreference=.both, enabledSources=[.reddit,.wallhaven,.pexels,.bing], autoChange=.off, autoChangeKind=.photo, lastAutoChange=nil, pauseVideoOnBattery=true, pauseVideoWhenCovered=true, videoQuality=.uhd4K, lockScreenVideoEnabled=false, showLibraryOnLaunch=true, activeLiveWallpaper: Wallpaper?=nil`; `var selectedInterests: [Interest]`; `mutating func toggleInterest(_:)`; `mutating func addCustomInterest(named:) -> Interest?`; `mutating func removeCustomInterest(id:)`; `func isSelected(_:) -> Bool`
  - `final class SettingsStore { init(defaults: UserDefaults = .standard, key: String = "AppSettings.v1"); func load() -> AppSettings; func save(_:) }`
  - `struct LibraryState: Codable, Equatable, Sendable { var favorites, history, localVideos: [Wallpaper]; var blockedIDs: Set<String>; static let historyLimit = 100; func isFavorite(_ id: String) -> Bool; mutating func toggleFavorite(_:); mutating func recordApplied(_:); mutating func block(_ id: String); mutating func addLocalVideo(_:); mutating func removeLocalVideo(id:) }`
  - `final class LibraryFileStore { init(fileURL: URL); func load() -> LibraryState; func save(_:) throws }`
  - `struct PlaybackConditions: Equatable, Sendable { var screensAsleep=false, screenLocked=false, sessionActive=true, onBattery=false, desktopVisible=true, userPaused=false }`, `struct PlaybackPreferences: Equatable, Sendable { var pauseOnBattery=true, pauseWhenCovered=true }`, `enum PlaybackPolicy { static func shouldPlay(_:_:) -> Bool }`

- [ ] **Step 1: Failing tests**: `decodesEmptyJSONToDefaults`; `decodesPartialJSONKeepingDefaults` (`{"hasCompletedOnboarding":true,"selectedInterestIDs":["cars"]}` keeps those + defaults elsewhere); `roundTripsThroughStore` (UserDefaults suite); `selectedInterestsKeepOrderSkipUnknownIncludeCustom`; `toggleInterestAddsThenRemoves`; `addCustomInterestSelectsAndDedupes`; `removeCustomInterestDeselects`; `autoChangeIsDue` (off never; hourly: nil last → due, 59 min → not, 60 min → due); `toggleFavoriteAddsThenRemoves`; `recordAppliedMovesToFrontAndCaps` (101 distinct → 100, re-apply moves to front without duplicate); `fileStoreRoundTrip` (temp dir); `missingFileLoadsEmptyState`; `playsWhenAllClear`; `pausesWhenAsleepLockedInactiveOrUserPaused`; `batteryPausesOnlyWhenPreferred`; `coveredPausesOnlyWhenPreferred`.
- [ ] **Step 2: Run tests**; expected FAIL.
- [ ] **Step 3: Implement** (custom `init(from:)` with `decodeIfPresent` everywhere).
- [ ] **Step 4: Run tests**; expected PASS.
- [ ] **Step 5: Commit** `feat(core): settings, library state and playback policy`.

### Task 6: Lock-screen store editors (pure)

**Files:**
- Create: `LockScreen/WallpaperStoreEditor.swift`, `LockScreen/AerialManifestEditor.swift`
- Test: `WallpaperStoreEditorTests.swift`, `AerialManifestEditorTests.swift`

Technique adapted from Mural (MIT, © 2026 Aleksey Tkachenko): the `Idle` project in `~/Library/Application Support/com.apple.wallpaper/Store/Index.plist` is the screen saver shown over the lock screen; every `Idle` (Displays, SystemDefault, Spaces) must be written; custom videos are registered in `…/aerials/manifest/entries.json` with the movie in `…/aerials/videos/<id>.mov`.

**Interfaces:**
- Produces:
  - `enum WallpaperStoreEditor { static let aerialsProvider = "com.apple.wallpaper.choice.aerials"; static func aerialConfiguration(assetID: String) throws -> Data; static func settingIdle(in store: [String: Any], provider: String, configuration: Data, now: Date) -> (store: [String: Any], count: Int); static func idleMatches(in store: [String: Any], provider: String, configuration: Data) -> Bool }`
  - `enum AerialManifestEditor { static let assetID = "5F0A1C2E-7B3D-4E8A-9C1F-0A11F1E00001"; static let categoryID = "5F0A1C2E-7B3D-4E8A-9C1F-0A11F1E000C1"; static let subcategoryID = "5F0A1C2E-7B3D-4E8A-9C1F-0A11F1E000C2"; static func registering(title: String, movieURL: URL, previewURL: URL, in manifest: [String: Any]?) -> [String: Any]; static func removingOurEntries(from manifest: [String: Any]) -> [String: Any] }` (one stable asset id, so re-installing replaces the previous lock-screen video instead of piling up entries)

Asset dictionary keys (from Mural): `id, url-4K-SDR-240FPS, previewImage, accessibilityLabel, localizedNameKey, categories:[categoryID], subcategories:[subcategoryID], preferredOrder 0, includeInShuffle false, showInTopLevel true, pointsOfInterest {}, shotID`. Category name "RedditWallpaper".

- [ ] **Step 1: Failing tests**: `writesEveryIdleScope` (synthetic store with `Displays.d1.Idle`, `SystemDefault.Idle`, `Spaces.s1.Default.Idle` → count 3, each `Content.Choices[0].Provider` == aerials, `Configuration` == data); `leavesDesktopUntouched`; `copiesEncodedOptionValuesFromSameProvider`; `idleMatchesAfterWrite`; `aerialConfigurationDecodesToAssetID`; `registersIntoEmptyManifest` (nil → version/assets/categories with our asset first); `reRegisteringReplacesInsteadOfDuplicating`; `preservesAppleAssets`; `removingOurEntriesKeepsAppleAssets`.
- [ ] **Step 2: Run tests**; expected FAIL.
- [ ] **Step 3: Implement**.
- [ ] **Step 4: Run tests**; expected PASS.
- [ ] **Step 5: Commit** `feat(core): wallpaper store and aerial manifest editors`.

### Task 7: App services (stills, cache, keychain, power, schedule, login)

**Files:** Create `Services/KeychainStore.swift`, `DownloadCache.swift`, `WallpaperApplier.swift`, `PowerSourceMonitor.swift`, `AutoChanger.swift`, `LaunchAtLogin.swift`. Delete `WallpaperManager.swift`, `DesktopManager.swift`, `RedditFetcher.swift`.

**Interfaces:**
- `enum KeychainStore { static func read(_ account: String) -> String?; static func write(_ value: String?, account: String) }`
- `final class DownloadCache { init(directory: URL); func localFile(for: Wallpaper, progress: ((Double) -> Void)?) async throws -> URL; func prune(keeping: Set<URL>, maxBytes: Int64) }` — files named `<sanitized id>.<preferredFileExtension>` under `~/Library/Application Support/RedditWallpaper/Cache/{Photos,Videos}`.
- `final class WallpaperApplier { func setStill(fileURL: URL) throws }` — every `NSScreen`, options `.imageScaling = scaleProportionallyUpOrDown`, `.allowClipping = true`.
- `final class PowerSourceMonitor { var onBattery: Bool; var onChange: ((Bool) -> Void)? ; func start() }` (IOKit `IOPSNotificationCreateRunLoopSource`).
- `final class AutoChanger { init(fire: @escaping () async -> Void); func update(interval: AutoChangeInterval, lastChange: Date?) }` — checks every 60 s with `isDue`, also on wake.
- `enum LaunchAtLogin { static var isEnabled: Bool; static func set(_ enabled: Bool) throws; static var wasLaunchedAtLogin: Bool }`.

- [ ] **Step 1: Implement**; **Step 2: push, expect `app-build` PASS**; **Step 3: Commit** `feat(app): download cache, stills, keychain, power, schedule`.

### Task 8: Live wallpaper engine

**Files:** Create `Services/VideoWallpaperController.swift`.

**Interfaces:**
- `final class VideoWallpaperController { var current: Wallpaper?; var isPlaying: Bool; var preferences: PlaybackPreferences; init(applier: WallpaperApplier); func play(fileURL: URL, wallpaper: Wallpaper) throws; func stop(); func setUserPaused(_: Bool) }`
- One `AVQueuePlayer` + `AVPlayerLooper`, `isMuted = true`, `preventsDisplaySleepDuringVideoPlayback = false`; one borderless window per screen at level `CGWindowLevelForKey(.desktopWindow) + 1`, `[.canJoinAllSpaces, .stationary, .ignoresCycle]`, `ignoresMouseEvents = true`, layer `AVPlayerLayer(videoGravity: .resizeAspectFill)`.
- Inputs to `PlaybackPolicy`: screens sleep/wake, session resign/become active, `com.apple.screenIsLocked/Unlocked`, power source, window occlusion. Rebuild windows on `NSApplication.didChangeScreenParametersNotification`.
- On play: first frame (`AVAssetImageGenerator`) saved as JPEG and set as the still wallpaper so the lock screen and Mission Control match.

- [ ] **Step 1: Implement**; **Step 2: CI `app-build` PASS**; **Step 3: Commit** `feat(app): live video wallpapers behind desktop icons`.

### Task 9: App model, feeds, windows, delegate

**Files:** Create `App/AppModel.swift`, `App/FeedController.swift`, `App/LibraryCollection.swift`, `App/WindowCoordinator.swift`, `App/AppDelegate.swift`; rewrite `RedditWallpaperApp.swift`.

**Interfaces:**
- `enum LibraryCollection: Hashable { case forYou, today, redditPicks, interest(Interest), search(String), favorites, history, myVideos; var title: String; var symbol: String; var isRemote: Bool; func feedRequest(settings: AppSettings, kind: MediaKind, sort: SortOrder, page: Int, blocked: Set<String>) -> FeedRequest? }` (`forYou` → all selected interests, or `.general` if none; `today` → `.general` with only Bing enabled; `redditPicks` → `.general` with only Reddit).
- `@Observable final class FeedController { private(set) var items: [Wallpaper]; isLoading; errors: [SourceError]; isExhausted; init(model: AppModel); func load(collection:kind:sort:) async; func loadMore() async }` (local collections read from `LibraryState`).
- `@Observable final class AppModel { var settings: AppSettings { didSet save }; var library: LibraryState; var pexelsKey: String?; var activeWallpaper: Wallpaper?; var busyID: String?; var lastError: String?; let video: VideoWallpaperController; func feedService() -> FeedService; func apply(_ w: Wallpaper) async; func applyRandom(kind: MediaKind) async; func toggleFavorite(_:); func hide(_:); func importVideo(from url: URL) throws; func stopLiveWallpaper(); func completeOnboarding(); func setPexelsKey(_:) }`
- `final class WindowCoordinator { init(model: AppModel); func showLibrary(collection: LibraryCollection?); func showSettings(); func showOnboarding() }` — `.regular` activation policy while any window is open, `.accessory` otherwise.
- AppDelegate: keeps the popover (now 360×600) + status item; on launch: restore live wallpaper (if file exists), start `AutoChanger`, lock-screen monitor; onboarding if not completed, else Library if `showLibraryOnLaunch && !LaunchAtLogin.wasLaunchedAtLogin`; `applicationShouldHandleReopen` → Library.

- [ ] **Step 1: Implement**; **Step 2: CI PASS**; **Step 3: Commit** `feat(app): app model, feed paging and window management`.

### Task 10: Shared views + menu bar popover

**Files:** Create `Views/Shared/{SymbolImage,ThumbnailView,InterestPicker,SourceBadge}.swift`, `Views/MenuBar/MenuBarView.swift`; delete `ContentView.swift`.

Popover: header (title, shuffle, refresh), Photos | Live segmented control, interest chips ("For You" + selected interests), card list using thumbnails only (16:9, source badge, quality badge, Set button, heart), empty/error/"add Pexels key" states, footer (Open Library, Settings, Quit). `SymbolImage` falls back to `"photo"` when an SF Symbol name doesn't exist.

- [ ] **Step 1: Implement** (invoke frontend-design guidance first); **Step 2: CI PASS**; **Step 3: Commit** `feat(app): interest-aware menu bar popover`.

### Task 11: Library window

**Files:** Create `Views/Library/{LibraryView,WallpaperGrid,WallpaperCard,WallpaperDetailView}.swift`.

`NavigationSplitView`: sidebar sections Discover (For You, Today on Bing, Reddit Picks), Your Interests (+ "Edit Interests…"), Your Collection (Favorites, History, My Videos). Toolbar: kind picker, sort menu, `.searchable` (→ `.search`), Import Video (My Videos), refresh. Adaptive grid (min 230 pt), infinite scroll, error banner with "Open Settings" for key errors. Detail sheet: large preview (image or muted looping `AVPlayer`), metadata + credit link, Set as Wallpaper ("Desktop & Lock Screen" for photos), Lock Screen (Experimental) for videos when enabled, Favorite, Hide, Open Source Page.

- [ ] **Step 1: Implement**; **Step 2: CI PASS**; **Step 3: Commit** `feat(app): library window with sorted collections`.

### Task 12: Onboarding + Settings

**Files:** Create `Views/Onboarding/OnboardingView.swift`, `Views/Settings/SettingsView.swift`.

Onboarding steps: Welcome → Interests (`InterestPicker`, custom field, Continue needs ≥ 1) → Wallpaper types (Photos/Live toggles, optional Pexels key with link to `https://www.pexels.com/api/`) → Finish (`completeOnboarding`, open Library). Settings tabs: Interests, Sources (toggles + Pexels key), Auto-Change (interval, kind, Change Now), Live Wallpapers (pause on battery, pause when covered, quality, stop, import, links to MotionBGs/MoeWalls), Lock Screen (explanation, experimental toggle, Restore, Start Screen Saver), General (launch at login, show Library on launch, redo onboarding).

- [ ] **Step 1: Implement**; **Step 2: CI PASS**; **Step 3: Commit** `feat(app): onboarding and settings`.

### Task 13: Experimental lock-screen video

**Files:** Create `Services/VideoTranscoder.swift`, `Services/LockScreenService.swift`; wire into AppModel/Detail/Settings.

**Interfaces:**
- `enum VideoTranscoder { static func makeLockScreenMovie(from: URL, to: URL) async throws; static func writePreview(of: URL, to: URL) async throws }` (video-only composition, HEVC highest quality preset, `.mov`).
- `final class LockScreenService { var isAvailable: Bool; var isActive: Bool; func install(videoFile: URL, title: String) async throws; func restore() throws; func reapplyIfNeeded(); func startScreenSaver() }` — refuses while System Settings (`com.apple.systempreferences`) runs; backs up to `~/Library/Application Support/RedditWallpaper/LockScreenBackup/` once; restarts `WallpaperAgent` via `/usr/bin/killall`; checks every 60 s while enabled.

- [ ] **Step 1: Implement**; **Step 2: CI PASS**; **Step 3: Commit** `feat(app): experimental live lock screen and screen saver`.

### Task 14: Docs and final verification

**Files:** Modify `README.md`; create `THIRD_PARTY_NOTICES.md` (Mural MIT notice).

- [ ] **Step 1:** README: features, sources + credit rules, Pexels key, live wallpapers, lock screen truth table (still = automatic; video = experimental screen saver layer; FileVault pre-boot screen not changeable), building, CI, distribution notes (Developer ID + notarization, shared API key limits).
- [ ] **Step 2:** Final CI run: both jobs PASS; read logs for warnings that indicate real bugs.
- [ ] **Step 3: Commit** `docs: describe interests, sources, live and lock screen wallpapers` and push.
