import Foundation
import AppKit
import SwiftUI
import Combine

class WallpaperManager: ObservableObject {
    static let shared = WallpaperManager()
    
    private let fileManager = FileManager.default
    
    private func getWallpaperDirectory() -> URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let appDirectory = appSupport.appendingPathComponent("RedditWallpaper")
        
        if !fileManager.fileExists(atPath: appDirectory.path) {
            try? fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true)
        }
        
        return appDirectory
    }
    
    func downloadAndSet(post: RedditPost) async throws {
        guard let url = URL(string: post.url) else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        
        let fileName = "current_wallpaper_" + UUID().uuidString + ".jpg"
        let fileURL = getWallpaperDirectory().appendingPathComponent(fileName)
        
        try data.write(to: fileURL)
        
        // Clean up older wallpapers to save space
        cleanupOldWallpapers(except: fileURL)
        
        // Apply to desktop
        DispatchQueue.main.async {
            DesktopManager.setWallpaper(url: fileURL)
        }
    }
    
    private func cleanupOldWallpapers(except current: URL) {
        let dir = getWallpaperDirectory()
        do {
            let files = try fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
            for file in files {
                if file != current {
                    try? fileManager.removeItem(at: file)
                }
            }
        } catch {
            print("Cleanup error: \(error)")
        }
    }
}
