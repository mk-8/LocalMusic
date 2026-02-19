import AVFoundation
import UIKit

/// Extracts ID3/MP4 metadata from audio files using AVAsset.
enum MetadataService {
    struct SongMeta {
        var title: String
        var artist: String
        var duration: Double
        var artworkData: Data?
    }

    static func extract(from url: URL) async -> SongMeta {
        let asset = AVURLAsset(url: url)
        var title = humanReadableName(from: url)
        var artist = "Unknown Artist"
        var artworkData: Data?

        let duration: Double
        if let d = try? await asset.load(.duration),
           d.isValid && !d.isIndefinite {
            let secs = CMTimeGetSeconds(d)
            duration = secs.isFinite ? secs : 0
        } else {
            duration = 0
        }

        if let metadata = try? await asset.load(.commonMetadata) {
            for item in metadata {
                guard let key = item.commonKey else { continue }
                switch key {
                case .commonKeyTitle:
                    if let val = try? await item.load(.stringValue), !val.isEmpty {
                        title = val
                    }
                case .commonKeyArtist:
                    if let val = try? await item.load(.stringValue), !val.isEmpty {
                        artist = val
                    }
                case .commonKeyArtwork:
                    if let val = try? await item.load(.dataValue) {
                        if let img = UIImage(data: val),
                           let jpeg = img.jpegData(compressionQuality: 0.7) {
                            artworkData = jpeg
                        } else {
                            artworkData = val
                        }
                    }
                default:
                    break
                }
            }
        }

        return SongMeta(title: title, artist: artist, duration: duration, artworkData: artworkData)
    }

    /// Strips the extension and replaces underscores/hyphens with spaces
    /// so bare filenames look reasonable as titles.
    private static func humanReadableName(from url: URL) -> String {
        url.deletingPathExtension()
            .lastPathComponent
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespaces)
    }
}
