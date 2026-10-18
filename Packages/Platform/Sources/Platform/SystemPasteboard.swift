import AppKit
import Core
import Foundation
import OSLog

/// `NSPasteboard.general`-backed implementation of the `Core` pasteboard protocols.
public final class SystemPasteboard: PasteboardReading, PasteboardWriting, @unchecked Sendable {
    private let pasteboard: NSPasteboard

    /// UTIs we persist. Control/convention types are read for metadata but not stored.
    private let capturedTypes: [String] = [
        UTIs.png, UTIs.tiff, UTIs.jpeg,
        UTIs.rtf, UTIs.html,
        UTIs.fileURL, UTIs.url,
        UTIs.color,
    ] + UTIs.audioTypeHints + [
        UTIs.utf8PlainText, UTIs.plainText, UTIs.text,
    ]

    private let log = Logger(subsystem: "com.example.shelf", category: "capture")

    public init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    public var changeCount: Int { pasteboard.changeCount }

    public func snapshot() -> PasteboardSnapshot? {
        guard let items = pasteboard.pasteboardItems, !items.isEmpty else { return nil }

        var reps: [CapturedRepresentation] = []
        for item in items {
            let available = Set(item.types.map(\.rawValue))
            for uti in capturedTypes where available.contains(uti) {
                if let data = item.data(forType: NSPasteboard.PasteboardType(uti)) {
                    reps.append(CapturedRepresentation(typeIdentifier: uti, data: data))
                }
            }
        }

        let allTypes = Set(pasteboard.types?.map(\.rawValue) ?? [])

        // Source app: the nspasteboard.org hint if set, else the frontmost app.
        // (Almost no app sets the hint — the fallback is what makes icons appear.)
        let hinted = pasteboard.string(forType: NSPasteboard.PasteboardType(UTIs.source))
        let frontmost = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let source = hinted ?? frontmost
        log.debug("capture: reps=\(reps.count) sourceHint=\(hinted ?? "nil", privacy: .public) frontmost=\(frontmost ?? "nil", privacy: .public) -> source=\(source ?? "nil", privacy: .public)")

        return PasteboardSnapshot(
            changeCount: pasteboard.changeCount,
            representations: reps,
            sourceBundleID: source,
            isConcealed: allTypes.contains(UTIs.concealed),
            isTransient: allTypes.contains(UTIs.transient)
        )
    }

    public func write(_ representations: [CapturedRepresentation], markSynthetic: Bool) {
        pasteboard.clearContents()
        let item = NSPasteboardItem()
        for rep in representations {
            item.setData(rep.data, forType: NSPasteboard.PasteboardType(rep.typeIdentifier))
        }
        if markSynthetic {
            // Flag our own write so the capture loop can ignore it.
            item.setString("com.example.shelf", forType: NSPasteboard.PasteboardType(UTIs.source))
        }
        pasteboard.writeObjects([item])
    }
}
