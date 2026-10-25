import Core
import Foundation

/// iCloud sync configuration. The opt-in flag lives in `PrivacySettings`; this
/// resolves the CloudKit container to mirror into at launch.
///
/// Sync requires a CloudKit-entitled, Developer ID signed build. In the default
/// ad-hoc open-source build the CloudKit store load fails and `PersistentStore`
/// falls back to local-only, so flipping this on is harmless but inert until the
/// app is signed with an iCloud container entitlement.
enum SyncSettings {
    /// Must match the `com.apple.developer.icloud-container-identifiers` entitlement.
    static let containerID = "iCloud.com.yindia.shelf"

    /// Container id to pass to `PersistentStore.onDisk`, or nil when sync is off.
    static func activeContainerID(_ settings: PrivacySettings) -> String? {
        settings.iCloudSyncEnabled ? containerID : nil
    }
}
