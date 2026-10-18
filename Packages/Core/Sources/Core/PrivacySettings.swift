import Foundation

/// Privacy preferences (Preferences → Privacy).
public struct PrivacySettings: Sendable, Codable, Equatable {
    /// Whether the Shelf panel is visible to screen sharing / recording / screenshots.
    public var showDuringScreenSharing: Bool
    /// Skip content marked confidential (nspasteboard concealed type).
    public var ignoreConfidential: Bool
    /// How long Clipboard History is kept (pinned + pinboard items are exempt).
    public var retention: RetentionWindow

    public init(showDuringScreenSharing: Bool = true, ignoreConfidential: Bool = true,
                retention: RetentionWindow = .month) {
        self.showDuringScreenSharing = showDuringScreenSharing
        self.ignoreConfidential = ignoreConfidential
        self.retention = retention
    }
}
