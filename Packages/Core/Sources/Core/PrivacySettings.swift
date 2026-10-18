import Foundation

/// Privacy preferences (Preferences → Privacy).
public struct PrivacySettings: Sendable, Codable, Equatable {
    /// Whether the Shelf panel is visible to screen sharing / recording / screenshots.
    public var showDuringScreenSharing: Bool
    /// Skip content marked confidential (nspasteboard concealed type).
    public var ignoreConfidential: Bool

    public init(showDuringScreenSharing: Bool = true, ignoreConfidential: Bool = true) {
        self.showDuringScreenSharing = showDuringScreenSharing
        self.ignoreConfidential = ignoreConfidential
    }
}
