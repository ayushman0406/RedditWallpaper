import Foundation
import WallpaperCore

/// Downloads wallpapers into Application Support and reuses files already there.
/// Files keep their real extension (a PNG stays .png) and a per-wallpaper name,
/// so macOS never shows a stale image cached under a reused path.
final class DownloadCache {
    let directory: URL
    private let session: URLSession

    init(directory: URL, session: URLSession = .shared) {
        self.directory = directory
        self.session = session
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    static var appSupportRoot: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("RedditWallpaper", isDirectory: true)
    }

    func fileURL(for wallpaper: Wallpaper) -> URL {
        let safeName = String(wallpaper.id.map { $0.isLetter || $0.isNumber || $0 == "-" ? $0 : "_" })
        return directory.appendingPathComponent(safeName).appendingPathExtension(wallpaper.preferredFileExtension)
    }

    func isCached(_ wallpaper: Wallpaper) -> Bool {
        wallpaper.mediaURL.isFileURL || FileManager.default.fileExists(atPath: fileURL(for: wallpaper).path)
    }

    /// The local file for `wallpaper`, downloading it first if needed.
    /// `progress` receives 0…1 on the main thread.
    func localFile(for wallpaper: Wallpaper, progress: ((Double) -> Void)? = nil) async throws -> URL {
        if wallpaper.mediaURL.isFileURL { return wallpaper.mediaURL }
        let destination = fileURL(for: wallpaper)
        if FileManager.default.fileExists(atPath: destination.path) { return destination }

        var request = URLRequest(url: wallpaper.mediaURL)
        request.setValue("RedditWallpaper/2.0 (macOS)", forHTTPHeaderField: "User-Agent")
        let delegate = progress.map { DownloadProgressDelegate(onProgress: $0) }
        let (temporary, response) = try await session.download(for: request, delegate: delegate)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            try? FileManager.default.removeItem(at: temporary)
            throw URLError(.badServerResponse)
        }
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: temporary, to: destination)
        return destination
    }

    /// Deletes the oldest files until the folder fits in `maxBytes`, never
    /// touching `keeping` (the current wallpaper, favorites in use, …).
    func prune(keeping: Set<URL>, maxBytes: Int64) {
        let keys: [URLResourceKey] = [.contentModificationDateKey, .fileSizeKey]
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: keys) else { return }
        let kept = Set(keeping.map(\.standardizedFileURL))
        let entries = files.compactMap { url -> (URL, Date, Int64)? in
            guard let values = try? url.resourceValues(forKeys: Set(keys)) else { return nil }
            return (url, values.contentModificationDate ?? .distantPast, Int64(values.fileSize ?? 0))
        }.sorted { $0.1 > $1.1 }
        var total: Int64 = 0
        for (url, _, size) in entries {
            total += size
            if total > maxBytes, !kept.contains(url.standardizedFileURL) {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }
}

/// Reports a download task's progress through its `Progress` object.
nonisolated final class DownloadProgressDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private let onProgress: (Double) -> Void
    private var observation: NSKeyValueObservation?

    init(onProgress: @escaping (Double) -> Void) {
        self.onProgress = onProgress
    }

    func urlSession(_ session: URLSession, didCreateTask task: URLSessionTask) {
        let callback = onProgress
        observation = task.progress.observe(\.fractionCompleted, options: [.new]) { progress, _ in
            let fraction = progress.fractionCompleted
            DispatchQueue.main.async { callback(fraction) }
        }
    }
}
