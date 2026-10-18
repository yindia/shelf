import AppKit
import Core
import Foundation
import QuickLookThumbnailing

/// Generates native thumbnails via `QLThumbnailGenerator` for image/video/audio/
/// pdf file URLs. Off-main; callers cache by item id.
public struct QuickLookThumbnailProvider: ThumbnailProviding {
    public init() {}

    public func thumbnailPNG(for fileURL: URL, size: CGSize, scale: CGFloat) async -> Data? {
        guard fileURL.isFileURL, FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let request = QLThumbnailGenerator.Request(
            fileAt: fileURL,
            size: size,
            scale: scale,
            representationTypes: .thumbnail
        )
        let generator = QLThumbnailGenerator.shared
        let cgImage: CGImage? = await withCheckedContinuation { continuation in
            generator.generateBestRepresentation(for: request) { rep, _ in
                continuation.resume(returning: rep?.cgImage)
            }
        }
        guard let cgImage else { return nil }
        let rep = NSBitmapImageRep(cgImage: cgImage)
        return rep.representation(using: .png, properties: [:])
    }
}
