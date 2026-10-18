import AppKit
import AVFoundation
import Core
import Foundation

/// Resolves duration/title/artist/artwork via AVFoundation, and a downsampled
/// waveform for audio that lacks cover art. All work is async/off-main.
public struct AVMediaInfoProvider: MediaInfoProviding {
    /// Number of amplitude buckets in the generated waveform.
    public var waveformBars: Int

    public init(waveformBars: Int = 48) {
        self.waveformBars = waveformBars
    }

    public func mediaInfo(for fileURL: URL, kind: ClipKind) async -> MediaInfo {
        guard fileURL.isFileURL else { return MediaInfo() }
        let asset = AVURLAsset(url: fileURL)

        var info = MediaInfo()
        if let duration = try? await asset.load(.duration) {
            info.durationSeconds = CMTimeGetSeconds(duration)
        }
        if let metadata = try? await asset.load(.commonMetadata) {
            info.title = await string(metadata, .commonKeyTitle)
            info.artist = await string(metadata, .commonKeyArtist)
            info.artworkPNG = await artwork(metadata)
        }
        // Waveform only when audio has no artwork (cheap visual fallback).
        if kind == .audio, info.artworkPNG == nil {
            info.waveform = await waveform(asset)
        }
        return info
    }

    private func string(_ items: [AVMetadataItem], _ key: AVMetadataKey) async -> String? {
        let matches = AVMetadataItem.metadataItems(from: items, withKey: key, keySpace: .common)
        return try? await matches.first?.load(.stringValue) ?? nil
    }

    private func artwork(_ items: [AVMetadataItem]) async -> Data? {
        let matches = AVMetadataItem.metadataItems(from: items, withKey: AVMetadataKey.commonKeyArtwork, keySpace: .common)
        let loaded = try? await matches.first?.load(.dataValue)
        guard let data = loaded ?? nil,
              let image = NSImage(data: data),
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff)
        else { return nil }
        return rep.representation(using: .png, properties: [:])
    }

    /// Reads PCM via `AVAssetReader` and buckets peak amplitudes into `waveformBars`.
    private func waveform(_ asset: AVURLAsset) async -> [Float]? {
        guard let track = try? await asset.loadTracks(withMediaType: .audio).first,
              let reader = try? AVAssetReader(asset: asset)
        else { return nil }

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
        ]
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: settings)
        guard reader.canAdd(output) else { return nil }
        reader.add(output)
        guard reader.startReading() else { return nil }

        var samples: [Float] = []
        samples.reserveCapacity(1 << 16)
        while let buffer = output.copyNextSampleBuffer(),
              let block = CMSampleBufferGetDataBuffer(buffer) {
            let length = CMBlockBufferGetDataLength(block)
            var data = Data(count: length)
            data.withUnsafeMutableBytes { raw in
                _ = CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: length, destination: raw.baseAddress!)
            }
            data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
                let ints = ptr.bindMemory(to: Int16.self)
                // Stride to cap work on long files.
                let stride = max(1, ints.count / 4096)
                var i = 0
                while i < ints.count {
                    samples.append(abs(Float(ints[i]) / Float(Int16.max)))
                    i += stride
                }
            }
            CMSampleBufferInvalidate(buffer)
            if samples.count > 20_000 { break }
        }
        guard !samples.isEmpty else { return nil }

        // Bucket into peak amplitudes.
        let bucketSize = max(1, samples.count / waveformBars)
        var bars: [Float] = []
        var i = 0
        while i < samples.count {
            let slice = samples[i ..< min(i + bucketSize, samples.count)]
            bars.append(slice.max() ?? 0)
            i += bucketSize
        }
        let peak = bars.max() ?? 1
        return peak > 0 ? bars.map { $0 / peak } : bars
    }
}
