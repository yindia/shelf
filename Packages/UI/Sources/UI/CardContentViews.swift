import AppKit
import Core
import SwiftUI

/// Renders the live preview body for an item, switched on `kind`.
struct CardContentView: View {
    let item: ClipItemModel

    var body: some View {
        switch item.kind {
        case .text:
            TextCardBody(text: item.plainText ?? "")
        case .richText:
            RichTextCardBody(rtf: item.data(for: UTIs.rtf), html: nil)
        case .html:
            RichTextCardBody(rtf: nil, html: item.data(for: UTIs.html))
        case .code:
            CodeCardBody(code: item.plainText ?? "")
        case .audio:
            AudioCardBody(item: item)
        case .video:
            VideoCardBody(item: item)
        case .image:
            ImageCardBody(item: item, data: imageData, dimensions: CardMeta.imageSize(item))
        case .color:
            ColorCardBody(colorData: item.data(for: UTIs.color))
        case .link:
            if item.isMapLink {
                MapCardBody(place: item.mapPlace, urlString: item.plainText ?? "")
            } else {
                LinkCardBody(urlString: item.plainText ?? "")
            }
        case .file:
            FileCardBody(item: item)
        case .unknown:
            UnknownCardBody()
        }
    }

    private var imageData: Data? {
        item.data(for: UTIs.png) ?? item.data(for: UTIs.tiff) ?? item.data(for: UTIs.jpeg)
    }
}

// MARK: - Text / rich text

struct TextCardBody: View {
    let text: String
    var body: some View {
        Text(text)
            .font(Theme.bodyFont)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .lineLimit(nil)
    }
}

/// RTF/HTML rendered with formatting via `NSAttributedString`.
struct RichTextCardBody: View {
    let rtf: Data?
    var html: Data?

    var body: some View {
        if let attributed {
            Text(attributed)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            TextCardBody(text: "(rich text)")
        }
    }

    private var attributed: AttributedString? {
        let data: Data?
        let options: [NSAttributedString.DocumentReadingOptionKey: Any]
        if let rtf {
            data = rtf
            options = [.documentType: NSAttributedString.DocumentType.rtf]
        } else if let html {
            data = html
            options = [.documentType: NSAttributedString.DocumentType.html]
        } else {
            return nil
        }
        guard let data, let ns = try? NSAttributedString(data: data, options: options, documentAttributes: nil) else {
            return nil
        }
        return try? AttributedString(ns, including: \.appKit)
    }
}

// MARK: - Image (edge-to-edge thumbnail)

/// A dimension/duration chip pinned to a corner of a media preview.
struct MediaChip: View {
    let text: String
    var body: some View {
        Text(text)
            .font(Theme.chipFont)
            .foregroundStyle(.white)
            .padding(.horizontal, 6).padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: Theme.chipCorner, style: .continuous).fill(.black.opacity(Theme.chipBgOpacity)))
            .padding(6)
    }
}

/// Fills the body edge-to-edge with an image, or a placeholder while loading.
struct PreviewFill: View {
    let image: NSImage?
    var body: some View {
        if let image {
            Image(nsImage: image)
                .resizable().aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity, maxHeight: .infinity).clipped()
        } else {
            ZStack {
                Rectangle().fill(.quaternary)
                ProgressView().controlSize(.small)
            }
        }
    }
}

struct ImageCardBody: View {
    let item: ClipItemModel
    let data: Data?
    let dimensions: CGSize?
    @EnvironmentObject private var loader: MediaPreviewLoader
    var body: some View {
        let stored = data.flatMap(NSImage.init(data:))
        let image = stored ?? loader.thumbnail(for: item, size: CGSize(width: Theme.cardWidth, height: 220))
        PreviewFill(image: image)
            .overlay(alignment: .bottomTrailing) {
                if let dimensions {
                    MediaChip(text: "\(Int(dimensions.width)) × \(Int(dimensions.height))")
                }
            }
    }
}

// MARK: - Video (poster frame + play overlay + duration chip)

struct VideoCardBody: View {
    let item: ClipItemModel
    @EnvironmentObject private var loader: MediaPreviewLoader
    var body: some View {
        let poster = loader.thumbnail(for: item, size: CGSize(width: Theme.cardWidth, height: 220))
        let info = loader.info(for: item)
        PreviewFill(image: poster)
            .overlay {
                Image(systemName: "play.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(Circle().fill(.black.opacity(0.45)))
            }
            .overlay(alignment: .bottomTrailing) {
                if let duration = info?.durationText { MediaChip(text: duration) }
            }
    }
}

// MARK: - Audio (artwork or waveform + title/artist/duration)

struct AudioCardBody: View {
    let item: ClipItemModel
    @EnvironmentObject private var loader: MediaPreviewLoader
    private var url: URL? { item.fileURLString.flatMap(URL.init(string:)) }
    var body: some View {
        let info = loader.info(for: item)
        VStack(spacing: 10) {
            Group {
                if let art = info?.artworkPNG, let image = NSImage(data: art) {
                    Image(nsImage: image).resizable().aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                } else if let bars = info?.waveform {
                    WaveformView(bars: bars).foregroundStyle(Theme.accent(for: .audio))
                } else {
                    WaveformView(bars: WaveformView.placeholder).foregroundStyle(.quaternary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(spacing: 1) {
                Text(info?.title ?? url?.deletingPathExtension().lastPathComponent ?? "Audio")
                    .font(Theme.bodyFont).lineLimit(1)
                if let detail = [info?.artist, info?.durationText].compactMap({ $0 }).joined(separator: " · ").nilIfEmpty {
                    Text(detail).font(Theme.footerFont).foregroundStyle(.secondary).lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

// MARK: - Map link (snapshot preview + place + domain)

struct MapCardBody: View {
    let place: MapLink.Place?
    let urlString: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            MapPreview(place: place)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: Theme.mapPreviewCorner))
            Text(place?.query ?? (URL(string: urlString)?.host ?? "Map"))
                .font(Theme.linkTitleFont).lineLimit(1)
            Text(URL(string: urlString)?.host ?? urlString)
                .font(Theme.footerFont).foregroundStyle(.secondary).lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: - Color (large swatch + hex)

struct ColorCardBody: View {
    let colorData: Data?
    var body: some View {
        let nsColor = Self.decode(colorData)
        VStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 10)
                .fill(nsColor.map(Color.init(nsColor:)) ?? .gray)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.black.opacity(0.08)))
            Text(nsColor.map(Self.hex) ?? "#------")
                .font(Theme.monoFont)
                .foregroundStyle(.primary)
        }
    }

    static func decode(_ data: Data?) -> NSColor? {
        guard let data else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data)
    }

    static func hex(_ color: NSColor) -> String {
        guard let rgb = color.usingColorSpace(.sRGB) else { return "#------" }
        return String(
            format: "#%02X%02X%02X",
            Int((rgb.redComponent * 255).rounded()),
            Int((rgb.greenComponent * 255).rounded()),
            Int((rgb.blueComponent * 255).rounded())
        )
    }
}

// MARK: - Link (favicon + title)

struct LinkCardBody: View {
    let urlString: String
    @State private var favicon: NSImage?

    private var url: URL? { URL(string: urlString) }
    private var host: String { url?.host ?? urlString }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Hero block fills the available vertical space (room for a thumbnail).
            ZStack {
                RoundedRectangle(cornerRadius: Theme.mapPreviewCorner, style: .continuous)
                    .fill(Theme.accent(for: .link).opacity(0.14))
                if let favicon {
                    Image(nsImage: favicon).resizable().aspectRatio(contentMode: .fit)
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else {
                    Image(systemName: "globe")
                        .font(.system(size: 40, weight: .regular))
                        .foregroundStyle(Theme.accent(for: .link))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Text(host).font(Theme.linkTitleFont).lineLimit(1)
            Text(urlString)
                .font(Theme.bodyFont)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .task { await loadFavicon() }
    }

    private func loadFavicon() async {
        guard let host = url?.host,
              let faviconURL = URL(string: "https://www.google.com/s2/favicons?sz=64&domain=\(host)"),
              let (data, _) = try? await URLSession.shared.data(from: faviconURL),
              let image = NSImage(data: data)
        else { return }
        favicon = image
    }
}

// MARK: - File

struct FileCardBody: View {
    let item: ClipItemModel
    @EnvironmentObject private var loader: MediaPreviewLoader
    private var fileURL: URL? { item.fileURLString.flatMap(URL.init(string:)) }

    var body: some View {
        // QuickLook thumbnail (covers PDF/doc previews); else the file's icon.
        let thumb = loader.thumbnail(for: item, size: CGSize(width: Theme.cardWidth, height: 220))
        VStack(spacing: 10) {
            if let thumb {
                Image(nsImage: thumb).resizable().aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            } else if let fileURL, fileURL.isFileURL {
                Image(nsImage: NSWorkspace.shared.icon(forFile: fileURL.path))
                    .resizable().frame(width: 56, height: 56)
            } else {
                Image(systemName: "doc.fill").font(.system(size: 44)).foregroundStyle(Theme.accent(for: .file))
            }
            Text(fileURL?.lastPathComponent ?? "File")
                .font(Theme.footerFont).foregroundStyle(.secondary)
                .lineLimit(1).truncationMode(.middle)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Code (lightweight syntax highlight)

struct CodeCardBody: View {
    let code: String
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        ScrollView {
            Text(SyntaxHighlighter.highlight(code, dark: colorScheme == .dark))
                .font(Theme.codeFont)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .textSelection(.disabled)
        }
    }
}

struct UnknownCardBody: View {
    var body: some View {
        Image(systemName: "questionmark.square.dashed")
            .font(.system(size: 34))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
