import AppKit
import AVFoundation
import Core
import Platform
import SwiftUI
import UI

// Renders the card strip to PNG in light + dark with REAL media previews.
// Generates temp image/video/audio files, synchronously resolves QuickLook
// thumbnails + AV metadata, and preloads them into the MediaPreviewLoader.

func tmp(_ name: String) -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent("shelf-snap-\(name)")
}

/// A gradient PNG written to disk + returned as PNG data.
func makeImageFile() -> (URL, Data, CGSize) {
    let size = NSSize(width: 480, height: 320)
    let image = NSImage(size: size)
    image.lockFocus()
    NSGradient(colors: [.systemTeal, .systemIndigo, .systemPink])?
        .draw(in: NSRect(origin: .zero, size: size), angle: 35)
    image.unlockFocus()
    let data = image.tiffRepresentation.flatMap { NSBitmapImageRep(data: $0) }?
        .representation(using: .png, properties: [:]) ?? Data()
    let url = tmp("image.png"); try? data.write(to: url)
    return (url, data, CGSize(width: 480, height: 320))
}

/// A short silent movie so QuickLook/AVFoundation produce a poster + duration.
func makeVideoFile() -> URL {
    let url = tmp("clip.mov")
    try? FileManager.default.removeItem(at: url)
    guard let writer = try? AVAssetWriter(outputURL: url, fileType: .mov) else { return url }
    let settings: [String: Any] = [AVVideoCodecKey: AVVideoCodecType.h264,
                                   AVVideoWidthKey: 480, AVVideoHeightKey: 320]
    let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: nil)
    writer.add(input)
    writer.startWriting(); writer.startSession(atSourceTime: .zero)
    for frame in 0..<30 {
        while !input.isReadyForMoreMediaData { usleep(1000) }
        var pb: CVPixelBuffer?
        CVPixelBufferCreate(nil, 480, 320, kCVPixelFormatType_32ARGB, nil, &pb)
        if let pb {
            CVPixelBufferLockBaseAddress(pb, [])
            let ctx = CGContext(data: CVPixelBufferGetBaseAddress(pb), width: 480, height: 320,
                                bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pb),
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)
            ctx?.setFillColor(NSColor(hue: CGFloat(frame) / 30, saturation: 0.7, brightness: 0.8, alpha: 1).cgColor)
            ctx?.fill(CGRect(x: 0, y: 0, width: 480, height: 320))
            CVPixelBufferUnlockBaseAddress(pb, [])
            adaptor.append(pb, withPresentationTime: CMTime(value: CMTimeValue(frame), timescale: 15))
        }
    }
    input.markAsFinished()
    let done = DispatchSemaphore(value: 0)
    writer.finishWriting { done.signal() }
    done.wait()
    return url
}

@MainActor
func sampleItems(imageURL: URL, imageData: Data, imageSize: CGSize, videoURL: URL, audioURL: URL) -> [ClipItemModel] {
    func rep(_ uti: String, _ data: Data) -> CapturedRepresentation { CapturedRepresentation(typeIdentifier: uti, data: data) }
    func text(_ s: String) -> Data { Data(s.utf8) }
    func fileURLRep(_ url: URL) -> CapturedRepresentation { rep(UTIs.fileURL, text(url.absoluteString)) }
    func item(_ kind: ClipKind, _ reps: [CapturedRepresentation], source: String?) -> ClipItemModel {
        ClipItemModel(id: UUID(), kind: kind, createdAt: Date().addingTimeInterval(-Double.random(in: 60...4000)),
                      fingerprint: UUID().uuidString, sourceBundleID: source,
                      listID: CollectionSeed.historyID, representations: reps)
    }
    return [
        item(.text, [rep(UTIs.utf8PlainText, text("The best code is the code never written."))], source: "com.apple.TextEdit"),
        item(.link, [rep(UTIs.utf8PlainText, text("https://pasteapp.io/home/explore"))], source: "com.apple.Safari"),
        item(.image, [rep(UTIs.png, imageData), fileURLRep(imageURL)], source: "com.apple.Photos"),
        item(.video, [fileURLRep(videoURL)], source: "com.apple.QuickTimePlayerX"),
        item(.audio, [fileURLRep(audioURL)], source: "com.apple.Music"),
        item(.link, [rep(UTIs.utf8PlainText, text("https://maps.apple.com/?ll=37.3349,-122.0090&q=Apple+Park"))], source: "com.apple.Maps"),
    ]
}

@MainActor
func render(scheme: ColorScheme, to path: String, items: [ClipItemModel], loader: MediaPreviewLoader, selectedIndex: Int, width: CGFloat = 1560, accent: Color? = nil) {
    let view = SnapshotStrip(
        collections: CollectionSeed.starters,
        selectedCollectionID: CollectionSeed.historyID,
        items: items, selectedIndex: selectedIndex, previewLoader: loader
    )
    .frame(width: width, height: Theme.panelHeight)
    .environment(\.colorScheme, scheme)
    .tint(accent)
    .background(scheme == .dark ? Color(red: 0.08, green: 0.08, blue: 0.09) : Color(red: 0.90, green: 0.88, blue: 0.85))

    let renderer = ImageRenderer(content: view)
    renderer.scale = 2
    guard let cg = renderer.cgImage else { print("render failed"); return }
    guard let data = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]) else { return }
    try? data.write(to: URL(fileURLWithPath: path))
    print("wrote \(path)")
}

// Generate media + thumbnails synchronously (ImageRenderer can't await).
let (imageURL, imageData, imageSize) = makeImageFile()
let videoURL = makeVideoFile()
// Use the generated video's audio-less track as the "audio" sample's poster source;
// for audio we fall back to a waveform placeholder (no artwork in a synthetic file).
let audioURL = videoURL

let thumbProvider = QuickLookThumbnailProvider()
let infoProvider = AVMediaInfoProvider()

final class Box<T>: @unchecked Sendable { var value: T? }

func sync<T: Sendable>(_ op: @Sendable @escaping () async -> T) -> T {
    let sem = DispatchSemaphore(value: 0)
    let box = Box<T>()
    Task.detached { box.value = await op(); sem.signal() }
    sem.wait()
    return box.value!
}

let items = MainActor.assumeIsolated {
    sampleItems(imageURL: imageURL, imageData: imageData, imageSize: imageSize, videoURL: videoURL, audioURL: audioURL)
}

MainActor.assumeIsolated {
    let loader = MediaPreviewLoader(thumbnailProvider: thumbProvider, infoProvider: infoProvider)
    for item in items {
        guard let url = item.fileURLString.flatMap(URL.init(string:)), url.isFileURL else { continue }
        let png = sync { await thumbProvider.thumbnailPNG(for: url, size: CGSize(width: Theme.cardWidth, height: 220), scale: 2) }
        let info = sync { await infoProvider.mediaInfo(for: url, kind: item.kind) }
        loader.preload(id: item.id, thumbnail: png.flatMap(NSImage.init(data:)), info: info)
    }

    render(scheme: .light, to: "build/cards-light.png", items: items, loader: loader, selectedIndex: 3)
    render(scheme: .dark, to: "build/cards-dark.png", items: items, loader: loader, selectedIndex: 3)
    render(scheme: .light, to: "build/cards-accent.png", items: items, loader: loader, selectedIndex: 2, accent: Color(hex: "#FF2D92"))
    // Narrow window: search + tabs + +/… must all stay visible (tabs scroll).
    render(scheme: .light, to: "build/cards-narrow-light.png", items: items, loader: loader, selectedIndex: 3, width: 720)
    render(scheme: .dark, to: "build/cards-narrow-dark.png", items: items, loader: loader, selectedIndex: 3, width: 720)
}
