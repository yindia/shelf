import Foundation

/// Seed data for the starter collections. Edit these to taste — names, colors,
/// icons, and order all live here.
public enum CollectionSeed {
    /// Stable id for the built-in "Clipboard History" collection (shows everything).
    public static let historyID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    /// Starter set, in display order. First entry is the default history collection.
    public static let starters: [Collection] = [
        Collection(id: historyID, name: "Clipboard History", colorHex: "#7C7A77", iconSymbol: "clock", order: 0, isDefault: true),
        Collection(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, name: "Links", colorHex: "#3E9E6B", iconSymbol: "link", order: 1),
        Collection(id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!, name: "Notes", colorHex: "#C79A1E", iconSymbol: "note.text", order: 2),
        Collection(id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!, name: "Code", colorHex: "#7B5EC0", iconSymbol: "chevron.left.forwardslash.chevron.right", order: 3),
        Collection(id: UUID(uuidString: "00000000-0000-0000-0000-000000000005")!, name: "Images", colorHex: "#3E73B5", iconSymbol: "photo", order: 4),
        Collection(id: UUID(uuidString: "00000000-0000-0000-0000-000000000006")!, name: "Colors", colorHex: "#D9792E", iconSymbol: "paintpalette", order: 5),
        Collection(id: UUID(uuidString: "00000000-0000-0000-0000-000000000007")!, name: "Files", colorHex: "#B5643E", iconSymbol: "doc", order: 6),
        Collection(id: UUID(uuidString: "00000000-0000-0000-0000-000000000008")!, name: "Media", colorHex: "#D1485B", iconSymbol: "play.rectangle", order: 7),
    ]
}
