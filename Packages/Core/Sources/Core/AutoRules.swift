import Foundation

/// How a rule matches a captured clip.
public enum RuleMatch: Sendable, Codable, Equatable {
    /// Match by classified content kind.
    case kind(ClipKind)
    /// Match when the clip's text matches this regex (applied to plain text/URL).
    case textPattern(String)
}

/// One auto-filing rule: when `match` matches, file the clip into `collectionID`.
public struct AutoRule: Sendable, Codable, Equatable, Identifiable {
    public var id: UUID
    public var enabled: Bool
    public var match: RuleMatch
    public var collectionID: UUID

    public init(id: UUID = UUID(), enabled: Bool = false, match: RuleMatch, collectionID: UUID) {
        self.id = id
        self.enabled = enabled
        self.match = match
        self.collectionID = collectionID
    }
}

/// Opt-in auto-categorization. `enabled` is the master switch; each rule also has
/// its own toggle. Defaults are OFF so capture stays predictable.
public struct AutoCategorizationRules: Sendable, Codable, Equatable {
    public var enabled: Bool
    public var rules: [AutoRule]

    public init(enabled: Bool = false, rules: [AutoRule] = []) {
        self.enabled = enabled
        self.rules = rules
    }

    /// Default rule set: master ON — built-in categories file content
    /// automatically with no user setup. Every content kind has a home.
    public static var defaults: AutoCategorizationRules {
        let s = CollectionSeed.starters
        func id(_ name: String) -> UUID { s.first { $0.name == name }?.id ?? CollectionSeed.historyID }
        func rule(_ kind: ClipKind, _ name: String) -> AutoRule {
            AutoRule(enabled: true, match: .kind(kind), collectionID: id(name))
        }
        return AutoCategorizationRules(enabled: true, rules: [
            rule(.link, "Links"),
            rule(.code, "Code"),
            rule(.image, "Images"),
            rule(.color, "Colors"),
            rule(.file, "Files"),
            rule(.video, "Media"),
            rule(.audio, "Media"),
            rule(.text, "Notes"),
            rule(.richText, "Notes"),
            rule(.html, "Notes"),
        ])
    }

    /// Resolves the destination collection for a captured clip. Returns `fallback`
    /// (the catch-all history collection) unless an enabled rule matches.
    public func route(kind: ClipKind, text: String?, fallback: UUID) -> UUID {
        guard enabled else { return fallback }
        for rule in rules where rule.enabled {
            switch rule.match {
            case .kind(let k):
                if k == kind { return rule.collectionID }
            case .textPattern(let pattern):
                if let text, !pattern.isEmpty,
                   let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
                   regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil {
                    return rule.collectionID
                }
            }
        }
        return fallback
    }
}
