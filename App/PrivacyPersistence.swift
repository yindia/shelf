import Core
import Foundation

/// Persists privacy settings in UserDefaults.
enum PrivacyPersistence {
    private static let key = "shelf.privacy"

    static func load() -> PrivacySettings {
        guard let data = UserDefaults.standard.data(forKey: key),
              let settings = try? JSONDecoder().decode(PrivacySettings.self, from: data)
        else { return PrivacySettings() }
        return settings
    }

    static func save(_ settings: PrivacySettings) {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
