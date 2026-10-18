import Core
import Foundation

/// Persists auto-categorization rules in UserDefaults as JSON.
enum AutoRulesPersistence {
    // v2: resets stale blobs saved before built-in kind rules shipped enabled.
    private static let key = "shelf.autoRules.v2"

    static func load() -> AutoCategorizationRules {
        guard let data = UserDefaults.standard.data(forKey: key),
              let rules = try? JSONDecoder().decode(AutoCategorizationRules.self, from: data)
        else { return .defaults }
        return rules
    }

    static func save(_ rules: AutoCategorizationRules) {
        if let data = try? JSONEncoder().encode(rules) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
