import AppKit
import Foundation

/// Lightweight update check against the GitHub Releases API (no extra deps).
/// Compares the latest published tag to the running version.
enum UpdateChecker {
    static let latestReleasePage = URL(string: "https://github.com/yindia/shelf/releases/latest")!
    private static let api = URL(string: "https://api.github.com/repos/yindia/shelf/releases/latest")!

    struct Update { let version: String }

    /// Returns a newer version if one is available, else nil.
    static func check() async -> Update? {
        var request = URLRequest(url: api)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 8
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = json["tag_name"] as? String
        else { return nil }

        let latest = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        let current = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        return isNewer(latest, than: current) ? Update(version: latest) : nil
    }

    /// Semantic-ish version compare (numeric components).
    static func isNewer(_ a: String, than b: String) -> Bool {
        let x = a.split(separator: ".").map { Int($0) ?? 0 }
        let y = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(x.count, y.count) {
            let xi = i < x.count ? x[i] : 0
            let yi = i < y.count ? y[i] : 0
            if xi != yi { return xi > yi }
        }
        return false
    }
}
