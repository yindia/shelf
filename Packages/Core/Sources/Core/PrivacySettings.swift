import Foundation

/// Privacy preferences (Preferences → Privacy).
public struct PrivacySettings: Sendable, Codable, Equatable {
    /// Whether the Shelf panel is visible to screen sharing / recording / screenshots.
    public var showDuringScreenSharing: Bool
    /// Skip content marked confidential (nspasteboard concealed type).
    public var ignoreConfidential: Bool
    /// How long Clipboard History is kept (pinned + pinboard items are exempt).
    public var retention: RetentionWindow
    /// Bundle ids of apps whose copies are never captured.
    public var excludedApps: Set<String>
    /// Opt-in iCloud sync (requires a CloudKit-entitled, Dev ID signed build;
    /// inert in the ad-hoc build). Applied at next launch.
    public var iCloudSyncEnabled: Bool

    public init(showDuringScreenSharing: Bool = true, ignoreConfidential: Bool = true,
                retention: RetentionWindow = .month, excludedApps: Set<String> = [],
                iCloudSyncEnabled: Bool = false) {
        self.showDuringScreenSharing = showDuringScreenSharing
        self.ignoreConfidential = ignoreConfidential
        self.retention = retention
        self.excludedApps = excludedApps
        self.iCloudSyncEnabled = iCloudSyncEnabled
    }

    enum CodingKeys: String, CodingKey {
        case showDuringScreenSharing, ignoreConfidential, retention, excludedApps, iCloudSyncEnabled
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        showDuringScreenSharing = try c.decodeIfPresent(Bool.self, forKey: .showDuringScreenSharing) ?? true
        ignoreConfidential = try c.decodeIfPresent(Bool.self, forKey: .ignoreConfidential) ?? true
        retention = try c.decodeIfPresent(RetentionWindow.self, forKey: .retention) ?? .month
        excludedApps = try c.decodeIfPresent(Set<String>.self, forKey: .excludedApps) ?? []
        iCloudSyncEnabled = try c.decodeIfPresent(Bool.self, forKey: .iCloudSyncEnabled) ?? false
    }
}
