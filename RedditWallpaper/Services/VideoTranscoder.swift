import AVFoundation
import CoreMedia
import Foundation

enum VideoTranscoder {
    enum TranscodeError: LocalizedError {
        case noVideoTrack
        case exportUnavailable

        var errorDescription: String? {
            switch self {
            case .noVideoTrack: "The file has no video track."
            case .exportUnavailable: "This Mac can't convert the video to HEVC."
            }
        }
    }

    /// The lock screen plays HEVC QuickTime movies without sound, like
    /// Apple's own aerials, so strip audio and re-encode.
    static func makeLockScreenMovie(from source: URL, to destination: URL) async throws {
        let asset = AVURLAsset(url: source)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw TranscodeError.noVideoTrack
        }
        let duration = try await asset.load(.duration)
        let composition = AVMutableComposition()
        guard let videoTrack = composition.addMutableTrack(
            withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw TranscodeError.noVideoTrack
        }
        try videoTrack.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: track, at: .zero)
        videoTrack.preferredTransform = try await track.load(.preferredTransform)

        guard let session = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHEVCHighestQuality) else {
            throw TranscodeError.exportUnavailable
        }
        try? FileManager.default.removeItem(at: destination)
        try await session.export(to: destination, as: .mov)
    }
}
