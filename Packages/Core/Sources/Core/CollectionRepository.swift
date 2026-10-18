import CoreData
import Foundation

extension CoreDataItemRepository: CollectionRepository {
    public func collections() async throws -> [Collection] {
        try await withCheckedThrowingContinuation { continuation in
            performCollections { context in
                let request = NSFetchRequest<NSManagedObject>(entityName: "List")
                request.sortDescriptors = [NSSortDescriptor(key: "displayOrder", ascending: true)]
                return try context.fetch(request).compactMap(Self.collection(from:))
            } resume: { continuation.resume(with: $0) }
        }
    }

    public func seedIfNeeded(_ seed: [Collection]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            storeContainer.performBackgroundTask { context in
                do {
                    let request = NSFetchRequest<NSManagedObject>(entityName: "List")
                    request.fetchLimit = 1
                    guard try context.count(for: request) == 0 else {
                        continuation.resume(returning: ())
                        return
                    }
                    for collection in seed {
                        Self.insert(collection, into: context)
                    }
                    try context.save()
                    continuation.resume(returning: ())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    @discardableResult
    public func create(_ collection: Collection) async throws -> Collection {
        try await withCheckedThrowingContinuation { continuation in
            performCollections { context in
                Self.insert(collection, into: context)
                try context.save()
                return [collection]
            } resume: { result in
                continuation.resume(with: result.map { $0.first ?? collection })
            }
        }
    }

    public func delete(collectionID: UUID, reassignTo: UUID) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            storeContainer.performBackgroundTask { context in
                do {
                    // Refile the collection's items into the fallback (keep clips).
                    let items = NSFetchRequest<NSManagedObject>(entityName: "Item")
                    items.predicate = NSPredicate(format: "listID == %@", collectionID as CVarArg)
                    for item in try context.fetch(items) {
                        item.setValue(reassignTo, forKey: "listID")
                    }
                    // Delete the List object.
                    let lists = NSFetchRequest<NSManagedObject>(entityName: "List")
                    lists.predicate = NSPredicate(format: "id == %@", collectionID as CVarArg)
                    for list in try context.fetch(lists) {
                        context.delete(list)
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

    /// Exposes the private container to this extension file.
    private var storeContainer: NSPersistentContainer { persistentContainer }

    private func performCollections(
        _ work: @escaping @Sendable (NSManagedObjectContext) throws -> [Collection],
        resume: @escaping @Sendable (Result<[Collection], Error>) -> Void
    ) {
        storeContainer.performBackgroundTask { context in
            do { resume(.success(try work(context))) } catch { resume(.failure(error)) }
        }
    }

    private static func insert(_ collection: Collection, into context: NSManagedObjectContext) {
        let object = NSEntityDescription.insertNewObject(forEntityName: "List", into: context)
        object.setValue(collection.id, forKey: "id")
        object.setValue(collection.name, forKey: "name")
        object.setValue(collection.colorHex, forKey: "colorHex")
        object.setValue(collection.iconSymbol, forKey: "iconSymbol")
        object.setValue(Int64(collection.order), forKey: "displayOrder")
        object.setValue(collection.isDefault, forKey: "isDefault")
    }

    private static func collection(from object: NSManagedObject) -> Collection? {
        guard
            let id = object.value(forKey: "id") as? UUID,
            let name = object.value(forKey: "name") as? String,
            let colorHex = object.value(forKey: "colorHex") as? String,
            let icon = object.value(forKey: "iconSymbol") as? String
        else { return nil }
        return Collection(
            id: id,
            name: name,
            colorHex: colorHex,
            iconSymbol: icon,
            order: Int(object.value(forKey: "displayOrder") as? Int64 ?? 0),
            isDefault: object.value(forKey: "isDefault") as? Bool ?? false
        )
    }
}
