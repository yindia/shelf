import Foundation

/// The classified kind of a clipboard entry. Drives which card/preview the UI renders.
public enum ClipKind: String, Sendable, Codable, CaseIterable {
    case text
    case richText
    case html
    case code
    case image
    case video
    case audio
    case color
    case link
    case file
    case unknown
}

/// A user pinboard. The card header color comes from the collection, not the kind.
public struct Collection: Identifiable, Sendable, Equatable, Hashable {
    public let id: UUID
    public var name: String
    public var colorHex: String
    public var iconSymbol: String
    public var order: Int
    /// The built-in "Clipboard History" collection shows every item (no filter).
    public var isDefault: Bool

    public init(id: UUID, name: String, colorHex: String, iconSymbol: String, order: Int, isDefault: Bool = false) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.iconSymbol = iconSymbol
        self.order = order
        self.isDefault = isDefault
    }
}

/// One raw representation copied from the pasteboard (a UTI + its bytes).
/// Platform-neutral so `Core` stays free of AppKit.
public struct CapturedRepresentation: Sendable, Equatable, Hashable {
    public let typeIdentifier: String
    public let data: Data

    public init(typeIdentifier: String, data: Data) {
        self.typeIdentifier = typeIdentifier
        self.data = data
    }
}

/// A point-in-time view of the pasteboard produced by `PasteboardReading`.
public struct PasteboardSnapshot: Sendable {
    public let changeCount: Int
    public let representations: [CapturedRepresentation]
    /// Source app bundle id, if advertised via `org.nspasteboard.source`.
    public let sourceBundleID: String?
    public let isConcealed: Bool
    public let isTransient: Bool

    public init(
        changeCount: Int,
        representations: [CapturedRepresentation],
        sourceBundleID: String?,
        isConcealed: Bool,
        isTransient: Bool
    ) {
        self.changeCount = changeCount
        self.representations = representations
        self.sourceBundleID = sourceBundleID
        self.isConcealed = isConcealed
        self.isTransient = isTransient
    }
}

/// What `CaptureManager` hands to the repository to persist a new entry.
public struct ClipItemDraft: Sendable, Equatable {
    public let kind: ClipKind
    public let fingerprint: String
    public let representations: [CapturedRepresentation]
    public let sourceBundleID: String?
    public let listID: UUID
    public let createdAt: Date
    /// Text recognized from an image via OCR (indexed for search), if any.
    public var ocrText: String?

    public init(
        kind: ClipKind,
        fingerprint: String,
        representations: [CapturedRepresentation],
        sourceBundleID: String?,
        listID: UUID,
        createdAt: Date = Date(),
        ocrText: String? = nil
    ) {
        self.kind = kind
        self.fingerprint = fingerprint
        self.representations = representations
        self.sourceBundleID = sourceBundleID
        self.listID = listID
        self.createdAt = createdAt
        self.ocrText = ocrText
    }
}

/// The plain, `Sendable` model the UI sees. Views never touch `NSManagedObject`.
public struct ClipItemModel: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let kind: ClipKind
    public let createdAt: Date
    public let fingerprint: String
    public let sourceBundleID: String?
    public let listID: UUID?
    public let representations: [CapturedRepresentation]
    /// User-given name (Edit → rename); overrides the derived title in the UI.
    public let userTitle: String?
    /// OCR-recognized text from an image, indexed for search.
    public let ocrText: String?

    public init(
        id: UUID,
        kind: ClipKind,
        createdAt: Date,
        fingerprint: String,
        sourceBundleID: String?,
        listID: UUID?,
        representations: [CapturedRepresentation],
        userTitle: String? = nil,
        ocrText: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.createdAt = createdAt
        self.fingerprint = fingerprint
        self.sourceBundleID = sourceBundleID
        self.listID = listID
        self.representations = representations
        self.userTitle = userTitle
        self.ocrText = ocrText
    }

    /// Returns the bytes for an exact UTI if present.
    public func data(for typeIdentifier: String) -> Data? {
        representations.first { $0.typeIdentifier == typeIdentifier }?.data
    }

    /// Best-effort plain text across the common string UTIs.
    public var plainText: String? {
        for uti in [UTIs.utf8PlainText, UTIs.plainText, UTIs.text] {
            if let data = data(for: uti), let s = String(data: data, encoding: .utf8) {
                return s
            }
        }
        return nil
    }

    /// The file URL string if this item carries one.
    public var fileURLString: String? {
        guard let data = data(for: UTIs.fileURL) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// A link's URL (from plain text / url rep).
    public var linkURL: URL? {
        if let text = plainText, let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return url
        }
        if let data = data(for: UTIs.url), let s = String(data: data, encoding: .utf8) {
            return URL(string: s)
        }
        return nil
    }

    /// True when the link points at a maps service (Apple/Google/geo).
    public var isMapLink: Bool { MapLink.isMap(linkURL) }

    /// Parsed map coordinate/place if resolvable, for the map preview.
    public var mapPlace: MapLink.Place? { MapLink.place(from: linkURL) }
}

/// Uniform Type Identifier constants used across capture and classification.
public enum UTIs {
    public static let plainText = "public.plain-text"
    public static let utf8PlainText = "public.utf8-plain-text"
    public static let text = "public.text"
    public static let rtf = "public.rtf"
    public static let html = "public.html"
    public static let png = "public.png"
    public static let tiff = "public.tiff"
    public static let jpeg = "public.jpeg"
    public static let fileURL = "public.file-url"
    public static let url = "public.url"
    public static let color = "com.apple.cocoa.pasteboard.color"
    public static let audio = "public.audio"
    /// Common audio type identifiers / file extensions used for detection.
    public static let audioTypeHints = ["public.audio", "public.mp3", "com.apple.m4a-audio",
                                        "public.aac-audio", "public.aiff-audio", "public.mpeg-4-audio"]
    public static let audioExtensions: Set<String> = ["mp3", "m4a", "wav", "aac", "aiff", "flac", "ogg"]
    public static let videoExtensions: Set<String> = ["mp4", "mov", "m4v", "avi", "mkv", "webm"]
    public static let pdf = "com.adobe.pdf"

    // nspasteboard.org conventions.
    public static let concealed = "org.nspasteboard.ConcealedType"
    public static let transient = "org.nspasteboard.TransientType"
    public static let autogenerated = "org.nspasteboard.AutoGeneratedType"
    public static let source = "org.nspasteboard.source"
}
