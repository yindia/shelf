import AppKit
import Core
import Foundation
import OSLog

/// Footer metadata string per kind: char count, image dimensions, or domain.
enum CardMeta {
    static func footer(for item: ClipItemModel) -> String {
        switch item.kind {
        case .text, .richText, .html, .code:
            let count = (item.plainText ?? "").count
            return "\(count) character\(count == 1 ? "" : "s")"
        case .image:
            if let size = imageSize(item) {
                return "\(Int(size.width)) × \(Int(size.height))"
            }
            return "image"
        case .audio:
            return URL(string: item.fileURLString ?? "")?.pathExtension.uppercased() ?? "audio"
        case .video:
            return URL(string: item.fileURLString ?? "")?.pathExtension.uppercased() ?? "video"
        case .link:
            if item.isMapLink { return item.linkURL?.host ?? "map" }
            return item.linkURL?.host ?? "link"
        case .color:
            return "color"
        case .file:
            let ext = URL(string: item.fileURLString ?? "")?.pathExtension.uppercased() ?? ""
            return ext.isEmpty ? "file" : ext
        case .unknown:
            return "unknown"
        }
    }

    /// Primary footer title (bold). A user-given name wins for any kind.
    static func title(for item: ClipItemModel) -> String? {
        if let name = item.userTitle, !name.isEmpty { return name }
        switch item.kind {
        case .link:
            if item.isMapLink { return item.mapPlace?.query ?? item.linkURL?.host }
            return item.linkURL?.host?.replacingOccurrences(of: "www.", with: "")
        case .file, .audio, .video:
            return item.fileURLString.flatMap(URL.init(string:))?.lastPathComponent
        default:
            return nil
        }
    }

    /// Secondary footer line (domain / path).
    static func subtitle(for item: ClipItemModel) -> String? {
        switch item.kind {
        case .link:
            return (item.plainText ?? "").replacingOccurrences(of: "https://", with: "")
                .replacingOccurrences(of: "http://", with: "")
        case .file, .audio, .video:
            return item.fileURLString.flatMap(URL.init(string:))?.deletingLastPathComponent().path
        default:
            return nil
        }
    }

    static func imageSize(_ item: ClipItemModel) -> CGSize? {
        for uti in [UTIs.png, UTIs.tiff, UTIs.jpeg] {
            if let data = item.data(for: uti), let img = NSImage(data: data), img.size != .zero {
                return img.size
            }
        }
        return nil
    }
}

/// Resolves a running/installed app's icon from its bundle id, cached.
enum SourceAppIcon {
    // NSCache is internally thread-safe; one fetch per bundle id (the spec's intent).
    nonisolated(unsafe) private static let cache = NSCache<NSString, NSImage>()
    private static let log = Logger(subsystem: "com.example.shelf", category: "source-icon")

    @MainActor
    static func image(for bundleID: String?) -> NSImage? {
        guard let bundleID, !bundleID.isEmpty, bundleID != "com.example.shelf" else {
            log.debug("icon: no usable bundleID (\(bundleID ?? "nil")) -> fallback symbol")
            return nil
        }
        if let hit = cache.object(forKey: bundleID as NSString) { return hit }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            log.debug("icon: \(bundleID) not resolvable to an app URL -> fallback symbol")
            return nil
        }
        if let bundle = Bundle(url: url), let name = appName(from: bundle) { names[bundleID] = name }
        let raw = NSWorkspace.shared.icon(forFile: url.path)
        // Bake a crisp fixed-size bitmap from the best representation so we never
        // display an upscaled rep. 80px covers ~26pt @3x displays.
        let crisp = Self.render(raw, pixels: 80)
        cache.setObject(crisp, forKey: bundleID as NSString)
        log.debug("icon: fetched for \(bundleID, privacy: .public)")
        return crisp
    }

    // Resolved human-readable app names, keyed by bundle id.
    nonisolated(unsafe) private static var names: [String: String] = [:]

    /// Localized app name for a bundle id (for VoiceOver labels), if resolvable.
    @MainActor
    static func name(for bundleID: String?) -> String? {
        guard let bundleID, !bundleID.isEmpty, bundleID != "com.example.shelf" else { return nil }
        if let hit = names[bundleID] { return hit }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID),
              let bundle = Bundle(url: url), let name = appName(from: bundle) else { return nil }
        names[bundleID] = name
        return name
    }

    private static func appName(from bundle: Bundle) -> String? {
        (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? bundle.bundleURL.deletingPathExtension().lastPathComponent
    }

    /// Draws `source` into a fresh square bitmap at `pixels`, high-interpolation.
    @MainActor
    private static func render(_ source: NSImage, pixels: Int) -> NSImage {
        let size = NSSize(width: pixels, height: pixels)
        let image = NSImage(size: size)
        image.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        source.draw(in: NSRect(origin: .zero, size: size),
                    from: .zero, operation: .copy, fraction: 1)
        image.unlockFocus()
        return image
    }
}
