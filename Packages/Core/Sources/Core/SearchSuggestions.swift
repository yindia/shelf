import Foundation

/// A filter the user can add to a Power Search, shown as an inline token and as
/// an autocomplete suggestion while typing.
public enum SearchToken: Identifiable, Equatable, Sendable {
    case kind(ClipKind)
    case app(bundleID: String, name: String)
    case date(DateFilter)
    case pinboard(id: UUID, name: String)

    public var id: String {
        switch self {
        case .kind(let k): "kind:\(k.rawValue)"
        case .app(let b, _): "app:\(b)"
        case .date(let d): "date:\(d.rawValue)"
        case .pinboard(let id, _): "pb:\(id.uuidString)"
        }
    }

    public var label: String {
        switch self {
        case .kind(let k): k.rawValue.capitalized
        case .app(_, let name): name
        case .date(let d): d.label
        case .pinboard(_, let name): name
        }
    }
}

/// Builds inline filter suggestions from a partial query, prefix-matching across
/// content kinds, source apps, date presets, and pinboards (reference order).
public enum SearchSuggestions {
    public static func matches(
        partial: String,
        apps: [(id: String, name: String)],
        collections: [Collection],
        active: SearchFilters,
        limit: Int = 6
    ) -> [SearchToken] {
        let q = partial.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return [] }

        var out: [SearchToken] = []
        for k in ClipKind.allCases where k != .unknown
            && !active.kinds.contains(k) && k.rawValue.lowercased().hasPrefix(q) {
            out.append(.kind(k))
        }
        for a in apps where !active.apps.contains(a.id) && a.name.lowercased().hasPrefix(q) {
            out.append(.app(bundleID: a.id, name: a.name))
        }
        for d in DateFilter.allCases where d != .any && active.date != d && d.label.lowercased().hasPrefix(q) {
            out.append(.date(d))
        }
        for c in collections where !c.isDefault
            && !active.pinboards.contains(c.id) && c.name.lowercased().hasPrefix(q) {
            out.append(.pinboard(id: c.id, name: c.name))
        }
        return Array(out.prefix(limit))
    }

    /// Active filters rendered as removable tokens (reference chip order).
    public static func activeTokens(_ f: SearchFilters, collections: [Collection],
                                    appName: (String) -> String) -> [SearchToken] {
        var out: [SearchToken] = []
        out += f.kinds.map { .kind($0) }
        out += f.apps.map { .app(bundleID: $0, name: appName($0)) }
        if f.date != .any { out.append(.date(f.date)) }
        out += f.pinboards.compactMap { id in
            collections.first { $0.id == id }.map { .pinboard(id: id, name: $0.name) }
        }
        return out
    }
}
