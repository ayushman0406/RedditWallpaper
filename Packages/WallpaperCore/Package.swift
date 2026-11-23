// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WallpaperCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "WallpaperCore", targets: ["WallpaperCore"]),
    ],
    targets: [
        .target(name: "WallpaperCore"),
        .testTarget(
            name: "WallpaperCoreTests",
            dependencies: ["WallpaperCore"]
        ),
    ],
    swiftLanguageModes: [.v5]
)
