import Foundation

/// How long clipboard history is kept before old items are auto-cleared.
/// Pinned items and items filed in a user pinboard are never removed.
public enum RetentionWindow: String, Sendable, Codable, CaseIterable {
    case day, week, month, year, forever

    public var label: String {
        switch self {
        case .day: "1 Day"
        case .week: "1 Week"
        case .month: "1 Month"
        case .year: "1 Year"
        case .forever: "Forever"
        }
    }

    /// The cutoff date; items older than this are expired. `nil` = keep forever.
    public func cutoff(from now: Date = Date()) -> Date? {
        switch self {
        case .day: now.addingTimeInterval(-86_400)
        case .week: now.addingTimeInterval(-7 * 86_400)
        case .month: now.addingTimeInterval(-30 * 86_400)
        case .year: now.addingTimeInterval(-365 * 86_400)
        case .forever: nil
        }
    }
}

/// Pure retention decision, unit-testable without CoreData.
public enum Retention {
    /// True when an item should be auto-cleared: older than `cutoff`, not pinned,
    /// and in Clipboard History (not a user pinboard).
    public static func isExpired(_ item: ClipItemModel, cutoff: Date) -> Bool {
        guard !item.isPinned else { return false }
        let inHistory = (item.listID ?? CollectionSeed.historyID) == CollectionSeed.historyID
        guard inHistory else { return false }
        return item.createdAt < cutoff
    }
}
