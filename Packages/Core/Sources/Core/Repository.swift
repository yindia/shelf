import CoreData
import Foundation

/// Read side of the item store. Returns plain `Sendable` models only.
public protocol ItemRepositoryReading: Sendable {
    /// Recent items, optionally filtered to one collection. `listID == nil`
    /// (or the default history collection) returns everything.
    func recentItems(limit: Int, listID: UUID?) async throws -> [ClipItemModel]
    /// Emits the full recent list on subscription and after every change.
    func changes(limit: Int, listID: UUID?) -> AsyncStream<[ClipItemModel]>
}

/// Read/write access to collections (pinboards).
public protocol CollectionRepository: Sendable {
    func collections() async throws -> [Collection]
    /// Inserts the starter set if the store has no collections yet.
    func seedIfNeeded(_ seed: [Collection]) async throws
    @discardableResult func create(_ collection: Collection) async throws -> Collection
    /// Deletes a collection; its items are refiled into `reassignTo` (not deleted).
    func delete(collectionID: UUID, reassignTo: UUID) async throws
}

/// Write side.
public protocol ItemRepositoryWriting: Sendable {
    /// Inserts a draft, or returns `nil` if an item with the same fingerprint
    /// already exists (in which case it is bumped to the top instead).
    @discardableResult
    func insert(_ draft: ClipItemDraft) async throws -> ClipItemModel?
    func delete(id: UUID) async throws
    /// Deletes every item (and its blobs).
    func deleteAll() async throws
    /// Clears history items older than `cutoff` (keeps pinned + pinboard items).
    func prune(olderThan cutoff: Date) async throws
    /// Refiles an item into a different collection.
    func setList(itemID: UUID, listID: UUID) async throws
    /// Renames an item (nil clears the custom name).
    func setTitle(itemID: UUID, title: String?) async throws
    /// Replaces an item's plain-text content (Edit in place).
    func setText(itemID: UUID, text: String) async throws
    /// Pins/unpins an item (pinned sorts to the top).
    func setPinned(itemID: UUID, pinned: Bool) async throws
    /// Replaces the bytes of one representation (image rotate, color edit).
    func setRepresentation(itemID: UUID, typeIdentifier: String, data: Data) async throws
}

public enum RepositoryError: Error {
    case entityMissing
}

/// CoreData-backed repository. All CoreData access happens inside
/// `performBackgroundTask`; only value models cross the boundary.
public final class CoreDataItemRepository: ItemRepositoryReading, ItemRepositoryWriting, @unchecked Sendable {
    private let store: PersistentStore
    private let defaultLimit: Int

    public init(store: PersistentStore, defaultLimit: Int = 200) {
        self.store = store
        self.defaultLimit = defaultLimit
    }

    /// Container access for repository extensions (e.g. collections).
    var persistentContainer: NSPersistentContainer { store.container }

    // MARK: Reading

    public func recentItems(limit: Int, listID: UUID? = nil) async throws -> [ClipItemModel] {
        try await withCheckedThrowingContinuation { continuation in
            store.container.performBackgroundTask { context in
                do {
                    let models = try Self.fetchRecent(limit: limit, listID: listID, in: context)
                    continuation.resume(returning: models)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public func changes(limit: Int, listID: UUID? = nil) -> AsyncStream<[ClipItemModel]> {
        AsyncStream { continuation in
            let observer = NotificationCenter.default.addObserver(
                forName: .NSManagedObjectContextDidSave,
                object: nil,
                queue: nil
            ) { [weak self] _ in
                guard let self else { return }
                Task {
                    if let models = try? await self.recentItems(limit: limit, listID: listID) {
                        continuation.yield(models)
                    }
                }
            }
            // Prime with current contents.
            Task {
                if let models = try? await self.recentItems(limit: limit, listID: listID) {
                    continuation.yield(models)
                }
            }
            let box = UncheckedBox(observer)
            continuation.onTermination = { _ in
                NotificationCenter.default.removeObserver(box.value)
            }
        }
    }

    // MARK: Writing

    @discardableResult
    public func insert(_ draft: ClipItemDraft) async throws -> ClipItemModel? {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ClipItemModel?, Error>) in
            store.container.performBackgroundTask { context in
                do {
                    // Dedup: if fingerprint exists, bump createdAt and skip insert.
                    let existing = NSFetchRequest<NSManagedObject>(entityName: "Item")
                    existing.predicate = NSPredicate(format: "fingerprint == %@", draft.fingerprint)
                    existing.fetchLimit = 1
                    if let dup = try context.fetch(existing).first {
                        dup.setValue(draft.createdAt, forKey: "createdAt")
                        try context.save()
                        continuation.resume(returning: nil)
                        return
                    }

                    guard let entity = NSEntityDescription.entity(forEntityName: "Item", in: context) else {
                        continuation.resume(throwing: RepositoryError.entityMissing)
                        return
                    }
                    let item = NSManagedObject(entity: entity, insertInto: context)
                    let id = UUID()
                    item.setValue(id, forKey: "id")
                    item.setValue(draft.kind.rawValue, forKey: "kind")
                    item.setValue(draft.createdAt, forKey: "createdAt")
                    item.setValue(draft.fingerprint, forKey: "fingerprint")
                    item.setValue(draft.sourceBundleID, forKey: "sourceBundleID")
                    item.setValue(draft.listID, forKey: "listID")
                    item.setValue(draft.ocrText, forKey: "ocrText")

                    for rep in draft.representations {
                        let dataEntity = NSEntityDescription.insertNewObject(forEntityName: "ItemData", into: context)
                        dataEntity.setValue(rep.typeIdentifier, forKey: "typeIdentifier")
                        dataEntity.setValue(rep.data, forKey: "data")
                        dataEntity.setValue(item, forKey: "item")
                    }

                    if let bundleID = draft.sourceBundleID {
                        item.setValue(try Self.application(for: bundleID, in: context), forKey: "application")
                    }

                    try context.save()
                    let model = ClipItemModel(
                        id: id,
                        kind: draft.kind,
                        createdAt: draft.createdAt,
                        fingerprint: draft.fingerprint,
                        sourceBundleID: draft.sourceBundleID,
                        listID: draft.listID,
                        representations: draft.representations
                    )
                    continuation.resume(returning: model)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public func setTitle(itemID: UUID, title: String?) async throws {
        try await mutate(itemID: itemID) { $0.setValue(title, forKey: "userTitle") }
    }

    public func setPinned(itemID: UUID, pinned: Bool) async throws {
        try await mutate(itemID: itemID) { $0.setValue(pinned, forKey: "isPinned") }
    }

    public func setRepresentation(itemID: UUID, typeIdentifier: String, data: Data) async throws {
        try await mutate(itemID: itemID) { object in
            let reps = (object.value(forKey: "representations") as? Set<NSManagedObject>) ?? []
            if let rep = reps.first(where: { ($0.value(forKey: "typeIdentifier") as? String) == typeIdentifier }) {
                rep.setValue(data, forKey: "data")
            }
        }
    }

    public func setText(itemID: UUID, text: String) async throws {
        try await mutate(itemID: itemID) { object in
            // Replace the plain-text representation blob in place.
            let data = Data(text.utf8)
            let reps = (object.value(forKey: "representations") as? Set<NSManagedObject>) ?? []
            if let textRep = reps.first(where: {
                ($0.value(forKey: "typeIdentifier") as? String) == UTIs.utf8PlainText
            }) {
                textRep.setValue(data, forKey: "data")
            } else if let any = reps.first {
                any.setValue(UTIs.utf8PlainText, forKey: "typeIdentifier")
                any.setValue(data, forKey: "data")
            }
        }
    }

    /// Fetch one Item by id, apply `change`, and save.
    private func mutate(itemID: UUID, _ change: @escaping @Sendable (NSManagedObject) -> Void) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            store.container.performBackgroundTask { context in
                do {
                    let request = NSFetchRequest<NSManagedObject>(entityName: "Item")
                    request.predicate = NSPredicate(format: "id == %@", itemID as CVarArg)
                    request.fetchLimit = 1
                    if let object = try context.fetch(request).first {
                        change(object)
                        try context.save()
                    }
                    continuation.resume(returning: ())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public func setList(itemID: UUID, listID: UUID) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            store.container.performBackgroundTask { context in
                do {
                    let request = NSFetchRequest<NSManagedObject>(entityName: "Item")
                    request.predicate = NSPredicate(format: "id == %@", itemID as CVarArg)
                    request.fetchLimit = 1
                    if let object = try context.fetch(request).first {
                        object.setValue(listID, forKey: "listID")
                        try context.save()
                    }
                    continuation.resume(returning: ())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public func prune(olderThan cutoff: Date) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            store.container.performBackgroundTask { context in
                do {
                    let request = NSFetchRequest<NSManagedObject>(entityName: "Item")
                    // Old, unpinned, Clipboard History (listID nil or the history id).
                    request.predicate = NSPredicate(
                        format: "createdAt < %@ AND isPinned == NO AND (listID == nil OR listID == %@)",
                        cutoff as CVarArg, CollectionSeed.historyID as CVarArg
                    )
                    for object in try context.fetch(request) { context.delete(object) }
                    try context.save()
                    continuation.resume(returning: ())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public func deleteAll() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            store.container.performBackgroundTask { context in
                do {
                    let request = NSFetchRequest<NSManagedObject>(entityName: "Item")
                    for object in try context.fetch(request) { context.delete(object) }
                    try context.save()
                    continuation.resume(returning: ())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public func delete(id: UUID) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            store.container.performBackgroundTask { context in
                do {
                    let request = NSFetchRequest<NSManagedObject>(entityName: "Item")
                    request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
                    for object in try context.fetch(request) {
                        context.delete(object)
                    }
                    try context.save()
                    continuation.resume(returning: ())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: Helpers

    private static func fetchRecent(limit: Int, listID: UUID?, in context: NSManagedObjectContext) throws -> [ClipItemModel] {
        let request = NSFetchRequest<NSManagedObject>(entityName: "Item")
        // Pinned first, then most-recent.
        request.sortDescriptors = [
            NSSortDescriptor(key: "isPinned", ascending: false),
            NSSortDescriptor(key: "createdAt", ascending: false),
        ]
        request.fetchLimit = limit
        // The default history collection (or nil) shows everything.
        if let listID, listID != CollectionSeed.historyID {
            request.predicate = NSPredicate(format: "listID == %@", listID as CVarArg)
        }
        return try context.fetch(request).compactMap(Self.model(from:))
    }

    private static func model(from object: NSManagedObject) -> ClipItemModel? {
        guard
            let id = object.value(forKey: "id") as? UUID,
            let kindRaw = object.value(forKey: "kind") as? String,
            let kind = ClipKind(rawValue: kindRaw),
            let createdAt = object.value(forKey: "createdAt") as? Date,
            let fingerprint = object.value(forKey: "fingerprint") as? String
        else { return nil }

        let reps = (object.value(forKey: "representations") as? Set<NSManagedObject> ?? [])
            .compactMap { dataObject -> CapturedRepresentation? in
                guard
                    let uti = dataObject.value(forKey: "typeIdentifier") as? String,
                    let data = dataObject.value(forKey: "data") as? Data
                else { return nil }
                return CapturedRepresentation(typeIdentifier: uti, data: data)
            }

        return ClipItemModel(
            id: id,
            kind: kind,
            createdAt: createdAt,
            fingerprint: fingerprint,
            sourceBundleID: object.value(forKey: "sourceBundleID") as? String,
            listID: object.value(forKey: "listID") as? UUID,
            representations: reps,
            userTitle: object.value(forKey: "userTitle") as? String,
            ocrText: object.value(forKey: "ocrText") as? String,
            isPinned: object.value(forKey: "isPinned") as? Bool ?? false
        )
    }

    private static func application(for bundleID: String, in context: NSManagedObjectContext) throws -> NSManagedObject {
        let request = NSFetchRequest<NSManagedObject>(entityName: "Application")
        request.predicate = NSPredicate(format: "bundleIdentifier == %@", bundleID)
        request.fetchLimit = 1
        if let existing = try context.fetch(request).first { return existing }
        let app = NSEntityDescription.insertNewObject(forEntityName: "Application", into: context)
        app.setValue(bundleID, forKey: "bundleIdentifier")
        return app
    }
}

/// Transfers a non-`Sendable` value across a concurrency boundary when the
/// programmer guarantees safe access (here: a one-shot observer token).
private struct UncheckedBox<T>: @unchecked Sendable {
    let value: T
    init(_ value: T) { self.value = value }
}
