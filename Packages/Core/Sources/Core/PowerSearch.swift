import Foundation

/// Date-range presets for Power Search.
public enum DateFilter: String, Sendable, Codable, CaseIterable {
    case any, today, last7Days, last30Days

    public var label: String {
        switch self {
        case .any: "Any Date"
        case .today: "Today"
        case .last7Days: "Last 7 Days"
        case .last30Days: "Last 30 Days"
        }
    }

    public func matches(_ date: Date, now: Date = Date()) -> Bool {
        switch self {
        case .any: return true
        case .today: return Calendar.current.isDate(date, inSameDayAs: now)
        case .last7Days: return date >= now.addingTimeInterval(-7 * 86_400)
        case .last30Days: return date >= now.addingTimeInterval(-30 * 86_400)
        }
    }
}

/// Structured Power Search filters: content type, source app, pinboard, date.
public struct SearchFilters: Sendable, Equatable {
    public var kinds: Set<ClipKind>
    public var apps: Set<String>          // source bundle ids
    public var pinboards: Set<UUID>
    public var date: DateFilter

    public init(kinds: Set<ClipKind> = [], apps: Set<String> = [],
                pinboards: Set<UUID> = [], date: DateFilter = .any) {
        self.kinds = kinds
        self.apps = apps
        self.pinboards = pinboards
        self.date = date
    }

    public var isEmpty: Bool {
        kinds.isEmpty && apps.isEmpty && pinboards.isEmpty && date == .any
    }
}

/// Power Search: applies filters + typo-tolerant text matching, then ranks by
/// relevance and recency.
public enum PowerSearch {
    public static func run(
        _ items: [ClipItemModel],
        text: String,
        filters: SearchFilters,
        now: Date = Date()
    ) -> [ClipItemModel] {
        let needle = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let scored: [(item: ClipItemModel, score: Int)] = items.compactMap { item in
            guard passesFilters(item, filters, now: now) else { return nil }
            if needle.isEmpty { return (item, 0) }
            guard let s = score(item, needle) else { return nil }
            return (item, s)
        }

        // Lower score = better match; tie-break by recency (newest first).
        return scored
            .sorted { a, b in
                a.score != b.score ? a.score < b.score : a.item.createdAt > b.item.createdAt
            }
            .map(\.item)
    }

    /// Items that pass the structured filters (no text match) — used to constrain
    /// the semantic-search fallback to the same filters as lexical search.
    public static func filter(_ items: [ClipItemModel], filters: SearchFilters, now: Date = Date()) -> [ClipItemModel] {
        items.filter { passesFilters($0, filters, now: now) }
    }

    private static func passesFilters(_ item: ClipItemModel, _ f: SearchFilters, now: Date) -> Bool {
        if !f.kinds.isEmpty, !f.kinds.contains(item.kind) { return false }
        if !f.apps.isEmpty {
            guard let app = item.sourceBundleID, f.apps.contains(app) else { return false }
        }
        if !f.pinboards.isEmpty {
            let member = item.listIDs.isEmpty ? [CollectionSeed.historyID] : item.listIDs
            if f.pinboards.isDisjoint(with: member) { return false }
        }
        if !f.date.matches(item.createdAt, now: now) { return false }
        return true
    }

    /// Match score across the item's searchable fields. `nil` = no match.
    /// 0 = prefix/exact, 10 = substring, 20 = fuzzy (typo-tolerant).
    static func score(_ item: ClipItemModel, _ needle: String) -> Int? {
        var best: Int?
        for field in fields(for: item).map({ $0.lowercased() }) {
            if field.hasPrefix(needle) { return 0 }
            if field.contains(needle) { best = min(best ?? 10, 10); continue }
            if fuzzyContains(field, needle) { best = min(best ?? 20, 20) }
        }
        return best
    }

    private static func fields(for item: ClipItemModel) -> [String] {
        var f: [String] = []
        if let t = item.userTitle { f.append(t) }
        if let t = item.plainText { f.append(t) }
        if let t = item.ocrText { f.append(t) }
        if item.kind == .link, let host = item.linkURL?.host { f.append(host) }
        if let file = item.fileURLString { f.append(file) }
        return f
    }

    /// True if any word in `haystack` is within a small edit distance of `needle`
    /// (typo tolerance scaled to the needle length).
    static func fuzzyContains(_ haystack: String, _ needle: String) -> Bool {
        guard needle.count >= 3 else { return false }
        let tolerance = needle.count <= 5 ? 1 : 2
        // Cap the word scan so pathologically long fields (e.g. OCR text) don't
        // stall ranking; only words near the needle length can match anyway.
        var scanned = 0
        for word in haystack.split(whereSeparator: { !$0.isLetter && !$0.isNumber }) {
            if abs(word.count - needle.count) <= tolerance,
               editDistance(String(word), needle) <= tolerance {
                return true
            }
            scanned += 1
            if scanned > 2000 { break }
        }
        return false
    }

    /// Levenshtein distance (bounded use; needles are short).
    static func editDistance(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var prev = Array(0...b.count)
        var curr = [Int](repeating: 0, count: b.count + 1)
        for i in 1...a.count {
            curr[0] = i
            for j in 1...b.count {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                curr[j] = min(prev[j] + 1, curr[j - 1] + 1, prev[j - 1] + cost)
            }
            swap(&prev, &curr)
        }
        return prev[b.count]
    }
}
