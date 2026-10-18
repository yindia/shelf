import CoreData

/// Builds the CoreData `NSManagedObjectModel` in code (no `.xcdatamodeld`).
///
/// Entities:
/// - `Item`       — one clipboard entry (kind, createdAt, fingerprint, source).
/// - `ItemData`   — one row per representation (typeIdentifier + data blob).
/// - `Application`— source app, deduped by bundle id.
/// - `List`       — a user pinboard/list grouping items (relationship scaffold for v1).
enum ClipModel {
    /// Built once per launch; the model is immutable after construction.
    nonisolated(unsafe) static let shared = make()

    static func make() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        let item = NSEntityDescription()
        item.name = "Item"
        item.managedObjectClassName = "NSManagedObject"

        let itemData = NSEntityDescription()
        itemData.name = "ItemData"
        itemData.managedObjectClassName = "NSManagedObject"

        let application = NSEntityDescription()
        application.name = "Application"
        application.managedObjectClassName = "NSManagedObject"

        let list = NSEntityDescription()
        list.name = "List"
        list.managedObjectClassName = "NSManagedObject"

        // MARK: Item attributes
        item.properties = [
            attr("id", .UUIDAttributeType),
            attr("kind", .stringAttributeType),
            attr("createdAt", .dateAttributeType),
            attr("fingerprint", .stringAttributeType),
            attr("sourceBundleID", .stringAttributeType, optional: true),
            attr("listID", .UUIDAttributeType, optional: true),
        ]

        // MARK: ItemData attributes
        itemData.properties = [
            attr("typeIdentifier", .stringAttributeType),
            binaryAttr("data"),
        ]

        // MARK: Application attributes
        application.properties = [
            attr("bundleIdentifier", .stringAttributeType),
            attr("name", .stringAttributeType, optional: true),
        ]

        // MARK: List attributes
        list.properties = [
            attr("id", .UUIDAttributeType),
            attr("name", .stringAttributeType),
            attr("colorHex", .stringAttributeType),
            attr("iconSymbol", .stringAttributeType),
            attr("displayOrder", .integer64AttributeType),
            attr("isDefault", .booleanAttributeType),
        ]

        // MARK: Relationships
        // Item 1 --- * ItemData  (cascade delete the blobs with the item)
        let itemToData = relationship("representations", destination: itemData, toMany: true, delete: .cascadeDeleteRule)
        let dataToItem = relationship("item", destination: item, toMany: false, delete: .nullifyDeleteRule)
        itemToData.inverseRelationship = dataToItem
        dataToItem.inverseRelationship = itemToData

        // Item * --- 1 Application
        let itemToApp = relationship("application", destination: application, toMany: false, delete: .nullifyDeleteRule)
        let appToItems = relationship("items", destination: item, toMany: true, delete: .nullifyDeleteRule)
        itemToApp.inverseRelationship = appToItems
        appToItems.inverseRelationship = itemToApp

        // Item * --- 1 List
        let itemToList = relationship("list", destination: list, toMany: false, delete: .nullifyDeleteRule)
        let listToItems = relationship("items", destination: item, toMany: true, delete: .cascadeDeleteRule)
        itemToList.inverseRelationship = listToItems
        listToItems.inverseRelationship = itemToList

        item.properties += [itemToData, itemToApp, itemToList]
        itemData.properties += [dataToItem]
        application.properties += [appToItems]
        list.properties += [listToItems]

        model.entities = [item, itemData, application, list]
        return model
    }

    private static func attr(
        _ name: String,
        _ type: NSAttributeType,
        optional: Bool = false
    ) -> NSAttributeDescription {
        let a = NSAttributeDescription()
        a.name = name
        a.attributeType = type
        a.isOptional = optional
        return a
    }

    private static func binaryAttr(_ name: String) -> NSAttributeDescription {
        let a = NSAttributeDescription()
        a.name = name
        a.attributeType = .binaryDataAttributeType
        a.allowsExternalBinaryDataStorage = true
        a.isOptional = false
        return a
    }

    private static func relationship(
        _ name: String,
        destination: NSEntityDescription,
        toMany: Bool,
        delete: NSDeleteRule
    ) -> NSRelationshipDescription {
        let r = NSRelationshipDescription()
        r.name = name
        r.destinationEntity = destination
        r.minCount = 0
        r.maxCount = toMany ? 0 : 1
        r.deleteRule = delete
        r.isOptional = true
        return r
    }
}
