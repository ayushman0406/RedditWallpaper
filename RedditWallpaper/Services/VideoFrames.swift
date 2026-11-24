import AppKit
import AVFoundation
import CoreMedia
import Foundation

/// Grabs still frames and basic facts from video files.
enum VideoFrames {
    /// Writes one frame of `video` as an image file (JPEG or PNG by extension).
    static func writeFrame(of video: URL, to destination: URL, at seconds: Double = 0.5) async throws {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: video))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 3840, height: 3840)
        let (image, _) = try await generator.image(at: CMTime(seconds: seconds, preferredTimescale: 600))
        let representation = NSBitmapImageRep(cgImage: image)
        let isPNG = destination.pathExtension.lowercased() == "png"
        guard let data = representation.representation(
            using: isPNG ? .png : .jpeg, properties: isPNG ? [:] : [.compressionFactor: 0.9]) else {
            throw CocoaError(.fileWriteUnknown)
        }
        try data.write(to: destination, options: .atomic)
    }

    /// Pixel size and duration of the first video track, when readable.
    static func info(of video: URL) async -> (width: Int?, height: Int?, duration: Double?) {
        let asset = AVURLAsset(url: video)
        let duration = try? await asset.load(.duration).seconds
        guard let track = try? await asset.loadTracks(withMediaType: .video).first,
              let size = try? await track.load(.naturalSize) else {
            return (nil, nil, duration)
        }
        return (Int(abs(size.width)), Int(abs(size.height)), duration)
    }
}
