import CoreData
import Foundation

/// Owns the CoreData stack built from the programmatic model.
///
/// Use `.inMemory()` in tests for an isolated, disk-free store.
public final class PersistentStore: @unchecked Sendable {
    public let container: NSPersistentContainer

    private init(container: NSPersistentContainer) {
        self.container = container
    }

    /// On-disk store under Application Support. `name` scopes the SQLite file.
    ///
    /// When `cloudKitContainerID` is non-nil the store mirrors to iCloud via
    /// `NSPersistentCloudKitContainer` (requires a CloudKit-entitled, Dev ID
    /// signed build). If the CloudKit store fails to load (e.g. not entitled in
    /// an ad-hoc build), it falls back to a plain local store so the app still
    /// works offline.
    public static func onDisk(name: String = "Shelf", cloudKitContainerID: String? = nil) throws -> PersistentStore {
        if let cloudKitContainerID {
            let cloud = NSPersistentCloudKitContainer(name: name, managedObjectModel: ClipModel.shared)
            configure(cloud, cloudKitContainerID: cloudKitContainerID)
            do {
                try load(cloud)
                return PersistentStore(container: cloud)
            } catch {
                // CloudKit unavailable/not entitled — fall back to local-only.
            }
        }
        let container = NSPersistentContainer(name: name, managedObjectModel: ClipModel.shared)
        configure(container, cloudKitContainerID: nil)
        try load(container)
        return PersistentStore(container: container)
    }

    private static func configure(_ container: NSPersistentContainer, cloudKitContainerID: String?) {
        container.persistentStoreDescriptions.forEach { description in
            // Inferred lightweight migration so additive model changes don't need a reset.
            description.shouldMigrateStoreAutomatically = true
            description.shouldInferMappingModelAutomatically = true
            if let cloudKitContainerID {
                // History tracking + remote-change notifications are required for
                // CloudKit mirroring to merge changes from other devices.
                description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
                description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
                description.cloudKitContainerOptions =
                    NSPersistentCloudKitContainerOptions(containerIdentifier: cloudKitContainerID)
            }
        }
    }

    /// Volatile store for tests.
    public static func inMemory() throws -> PersistentStore {
        let container = NSPersistentContainer(name: "ShelfTest", managedObjectModel: ClipModel.shared)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        try load(container)
        return PersistentStore(container: container)
    }

    private static func load(_ container: NSPersistentContainer) throws {
        var loadError: Error?
        container.loadPersistentStores { _, error in loadError = error }
        if let loadError { throw loadError }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
    }
}
