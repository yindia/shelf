import Foundation

/// A generated title + one-line summary for a clip.
public struct ClipSummary: Sendable, Equatable {
    public let title: String
    public let summary: String
    public init(title: String, summary: String) {
        self.title = title
        self.summary = summary
    }
}

/// On-device intelligence for clips (Apple Intelligence / Foundation Models).
/// Platform-free so `Core` stays portable; the real implementation lives in
/// `Platform` behind a `canImport(FoundationModels)` guard, with a no-op
/// fallback for machines/OSes without Apple Intelligence.
public protocol ClipIntelligence: Sendable {
    /// Whether an on-device model is available right now.
    var isAvailable: Bool { get }
    /// A short title + summary for long text, or nil when unavailable.
    func summarize(_ text: String) async -> ClipSummary?
    /// Pick the best-fitting collection name from `collections`, or nil.
    func categorize(_ text: String, into collections: [String]) async -> String?
}

/// Fallback used when Apple Intelligence isn't available (older OS / hardware,
/// or tests). All operations return nil.
public struct NoopClipIntelligence: ClipIntelligence {
    public init() {}
    public var isAvailable: Bool { false }
    public func summarize(_ text: String) async -> ClipSummary? { nil }
    public func categorize(_ text: String, into collections: [String]) async -> String? { nil }
}
