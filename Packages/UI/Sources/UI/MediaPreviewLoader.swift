import AppKit
import Core
import SwiftUI

/// Loads QuickLook thumbnails and AVFoundation media info on demand, caching by
/// item id so the carousel stays smooth. Generation happens off the main thread;
/// views show a placeholder until a result is published.
@MainActor
public final class MediaPreviewLoader: ObservableObject {
    @Published private var thumbnails: [UUID: NSImage] = [:]
    @Published private var infos: [UUID: MediaInfo] = [:]
    @Published private var linkImages: [UUID: NSImage] = [:]

    private let thumbnailProvider: ThumbnailProviding
    private let infoProvider: MediaInfoProviding
    private var inFlightThumbs: Set<UUID> = []
    private var inFlightInfos: Set<UUID> = []
    private var inFlightLinks: Set<UUID> = []

    public init(thumbnailProvider: ThumbnailProviding, infoProvider: MediaInfoProviding) {
        self.thumbnailProvider = thumbnailProvider
        self.infoProvider = infoProvider
    }

    /// Cached thumbnail if ready; otherwise kicks off a load and returns nil.
    public func thumbnail(for item: ClipItemModel, size: CGSize) -> NSImage? {
        if let hit = thumbnails[item.id] { return hit }
        guard let url = item.fileURLString.flatMap(URL.init(string:)), url.isFileURL else { return nil }
        guard !inFlightThumbs.contains(item.id) else { return nil }
        inFlightThumbs.insert(item.id)
        let id = item.id
        Task { [thumbnailProvider] in
            let png = await thumbnailProvider.thumbnailPNG(for: url, size: size, scale: 2)
            let image = png.flatMap(NSImage.init(data:))
            await MainActor.run {
                self.inFlightThumbs.remove(id)
                if let image { self.thumbnails[id] = image }
            }
        }
        return nil
    }

    /// Cached media info if ready; otherwise kicks off a load and returns nil.
    public func info(for item: ClipItemModel) -> MediaInfo? {
        if let hit = infos[item.id] { return hit }
        guard let url = item.fileURLString.flatMap(URL.init(string:)), url.isFileURL else { return nil }
        guard !inFlightInfos.contains(item.id) else { return nil }
        inFlightInfos.insert(item.id)
        let id = item.id
        let kind = item.kind
        Task { [infoProvider] in
            let info = await infoProvider.mediaInfo(for: url, kind: kind)
            await MainActor.run {
                self.inFlightInfos.remove(id)
                self.infos[id] = info
            }
        }
        return nil
    }

    /// Rich link artwork (og:image / apple-touch-icon / large favicon), async.
    public func linkImage(for item: ClipItemModel) -> NSImage? {
        if let hit = linkImages[item.id] { return hit }
        guard item.kind == .link, let url = item.linkURL, url.host != nil else { return nil }
        guard !inFlightLinks.contains(item.id) else { return nil }
        inFlightLinks.insert(item.id)
        let id = item.id
        Task {
            let data = await LinkArt.fetch(url)   // Sendable Data crosses the boundary
            await MainActor.run {
                self.inFlightLinks.remove(id)
                if let data, let image = NSImage(data: data) { self.linkImages[id] = image }
            }
        }
        return nil
    }

    /// Test/snapshot seam: inject a precomputed thumbnail/info/link image.
    public func preload(id: UUID, thumbnail: NSImage? = nil, info: MediaInfo? = nil, linkImage: NSImage? = nil) {
        if let thumbnail { thumbnails[id] = thumbnail }
        if let info { infos[id] = info }
        if let linkImage { linkImages[id] = linkImage }
    }
}
