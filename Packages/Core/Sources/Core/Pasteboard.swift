import Foundation

/// Read side of the pasteboard. `Platform` provides the `NSPasteboard`-backed
/// implementation; tests provide a mock. Keeps `Core` AppKit-free and testable.
public protocol PasteboardReading: Sendable {
    /// Monotonic counter that increments on every pasteboard change.
    var changeCount: Int { get }
    /// Current contents, or `nil` if empty/unreadable.
    func snapshot() -> PasteboardSnapshot?
}

/// Write side, used by paste-back to restore an item's representations.
public protocol PasteboardWriting: Sendable {
    /// Writes representations to the pasteboard. When `markSynthetic` is true the
    /// writer tags the contents so the capture loop ignores its own write.
    func write(_ representations: [CapturedRepresentation], markSynthetic: Bool)
}
