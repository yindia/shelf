import Foundation

/// Detects and parses map/geo links (Apple Maps, Google Maps, `geo:` URIs).
public enum MapLink {
    public struct Place: Sendable, Equatable {
        public let query: String?
        public let latitude: Double?
        public let longitude: Double?
        public init(query: String?, latitude: Double?, longitude: Double?) {
            self.query = query
            self.latitude = latitude
            self.longitude = longitude
        }
        public var hasCoordinate: Bool { latitude != nil && longitude != nil }
    }

    private static let mapHosts = ["maps.apple.com", "maps.google.com", "google.com/maps", "goo.gl/maps"]

    public static func isMap(_ url: URL?) -> Bool {
        guard let url else { return false }
        if url.scheme?.lowercased() == "geo" { return true }
        let full = url.absoluteString.lowercased()
        let host = url.host?.lowercased() ?? ""
        return mapHosts.contains { full.contains($0) || host.hasSuffix($0) }
    }

    /// Best-effort parse of a place name and/or lat/lng from the URL.
    public static func place(from url: URL?) -> Place? {
        guard let url, isMap(url) else { return nil }

        // geo:lat,lng
        if url.scheme?.lowercased() == "geo" {
            let parts = url.absoluteString.dropFirst(4).split(separator: ",")
            if parts.count >= 2, let lat = Double(parts[0]), let lng = Double(parts[1].prefix(while: { $0 != "?" })) {
                return Place(query: nil, latitude: lat, longitude: lng)
            }
        }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let items = components?.queryItems ?? []
        let query = items.first { $0.name == "q" || $0.name == "query" || $0.name == "daddr" }?.value

        // Apple: ?ll=lat,lng  ·  Google: ?ll= / @lat,lng in path
        if let ll = items.first(where: { $0.name == "ll" || $0.name == "sll" })?.value {
            let p = ll.split(separator: ",")
            if p.count == 2, let lat = Double(p[0]), let lng = Double(p[1]) {
                return Place(query: query, latitude: lat, longitude: lng)
            }
        }
        if let at = url.absoluteString.range(of: "@") {
            let tail = url.absoluteString[at.upperBound...]
            let p = tail.split(separator: ",")
            if p.count >= 2, let lat = Double(p[0]), let lng = Double(p[1]) {
                return Place(query: query, latitude: lat, longitude: lng)
            }
        }
        return Place(query: query, latitude: nil, longitude: nil)
    }
}
