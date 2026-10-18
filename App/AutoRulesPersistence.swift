import Core
import Foundation

/// Persists auto-categorization rules in UserDefaults as JSON.
enum AutoRulesPersistence {
    private static let key = "shelf.autoRules"

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
