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
    public static func onDisk(name: String = "Shelf") throws -> PersistentStore {
        let container = NSPersistentContainer(name: name, managedObjectModel: ClipModel.shared)
        // Inferred lightweight migration so additive model changes don't need a reset.
        container.persistentStoreDescriptions.forEach {
            $0.shouldMigrateStoreAutomatically = true
            $0.shouldInferMappingModelAutomatically = true
        }
        try load(container)
        return PersistentStore(container: container)
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
