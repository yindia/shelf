import Foundation

/// Metadata for a media item, resolved off the main thread by the platform.
public struct MediaInfo: Sendable, Equatable {
    public var durationSeconds: Double?
    public var title: String?
    public var artist: String?
    /// Embedded artwork (e.g. audio cover art) as PNG, if present.
    public var artworkPNG: Data?
    /// Downsampled waveform amplitudes in 0...1 for audio without artwork.
    public var waveform: [Float]?

    public init(
        durationSeconds: Double? = nil,
        title: String? = nil,
        artist: String? = nil,
        artworkPNG: Data? = nil,
        waveform: [Float]? = nil
    ) {
        self.durationSeconds = durationSeconds
        self.title = title
        self.artist = artist
        self.artworkPNG = artworkPNG
        self.waveform = waveform
    }

    /// `m:ss` / `h:mm:ss` formatting of the duration.
    public var durationText: String? {
        guard let total = durationSeconds, total.isFinite, total >= 0 else { return nil }
        let seconds = Int(total.rounded())
        let (h, m, s) = (seconds / 3600, (seconds % 3600) / 60, seconds % 60)
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }
}

/// Generates a thumbnail (PNG bytes) for a file URL. Implemented by the platform
/// with QuickLook; results should be cached by the caller's key.
public protocol ThumbnailProviding: Sendable {
    func thumbnailPNG(for fileURL: URL, size: CGSize, scale: CGFloat) async -> Data?
}

/// Resolves media metadata (duration/title/artist/artwork/waveform) off-main.
public protocol MediaInfoProviding: Sendable {
    func mediaInfo(for fileURL: URL, kind: ClipKind) async -> MediaInfo
}
