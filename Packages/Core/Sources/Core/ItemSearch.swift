import Foundation

/// Case-insensitive search across an item's text, user title, OCR text, and
/// (for links) its URL/host. Keeps search logic pure and unit-testable.
public enum ItemSearch {
    public static func matches(_ item: ClipItemModel, query: String) -> Bool {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return true }
        return haystacks(for: item).contains { $0.lowercased().contains(needle) }
    }

    public static func filter(_ items: [ClipItemModel], query: String) -> [ClipItemModel] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return items }
        return items.filter { matches($0, query: needle) }
    }

    private static func haystacks(for item: ClipItemModel) -> [String] {
        var fields: [String] = []
        if let t = item.userTitle { fields.append(t) }
        if let t = item.plainText { fields.append(t) }
        if let t = item.ocrText { fields.append(t) }
        if item.kind == .link, let host = item.linkURL?.host { fields.append(host) }
        if let file = item.fileURLString { fields.append(file) }
        return fields
    }
}
