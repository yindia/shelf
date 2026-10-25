import AppKit
import Foundation

/// Fetches rich link artwork off the main thread: Open Graph image, then
/// apple-touch-icon, then a large favicon. Returns nil when none resolves (the
/// UI then shows a generated monogram tile).
enum LinkArt {
    /// Rich link metadata: thumbnail bytes + page title (both Sendable).
    struct Metadata: Sendable {
        var imageData: Data?
        var title: String?
    }

    /// Fetches a page's thumbnail and title in one request where possible.
    static func fetchMetadata(_ url: URL) async -> Metadata {
        guard let host = url.host else { return Metadata() }
        var title: String?

        // 1) Parse the page head for og:image / og:title / apple-touch-icon.
        if let html = await html(for: url) {
            title = metaContent(html, property: "og:title") ?? htmlTitle(html)
            if let og = metaContent(html, property: "og:image"),
               let link = resolve(og, base: url), let data = await image(link) {
                return Metadata(imageData: data, title: title)
            }
            if let touch = linkHref(html, rel: "apple-touch-icon"),
               let link = resolve(touch, base: url), let data = await image(link) {
                return Metadata(imageData: data, title: title)
            }
        }
        // 2) Well-known apple-touch-icon path.
        if let scheme = url.scheme,
           let direct = URL(string: "\(scheme)://\(host)/apple-touch-icon.png"),
           let data = await image(direct) {
            return Metadata(imageData: data, title: title)
        }
        // 3) Large favicon fallback.
        if let fav = URL(string: "https://www.google.com/s2/favicons?sz=128&domain=\(host)") {
            return Metadata(imageData: await image(fav), title: title)
        }
        return Metadata(imageData: nil, title: title)
    }

    /// `<title>…</title>` text, trimmed.
    private static func htmlTitle(_ html: String) -> String? {
        firstGroup(html, "<title[^>]*>([^<]+)</title>")?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func html(for url: URL) async -> String? {
        var request = URLRequest(url: url)
        request.timeoutInterval = 6
        request.setValue("Mozilla/5.0 (Macintosh)", forHTTPHeaderField: "User-Agent")
        guard let (data, _) = try? await URLSession.shared.data(for: request) else { return nil }
        // Only the head matters; cap the parsed text.
        let slice = data.prefix(256 * 1024)
        return String(data: slice, encoding: .utf8) ?? String(decoding: slice, as: UTF8.self)
    }

    private static func image(_ url: URL) async -> Data? {
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let image = NSImage(data: data), image.size.width >= 16 else { return nil }
        _ = image
        return data
    }

    private static func metaContent(_ html: String, property: String) -> String? {
        // <meta property="og:image" content="..."> (property or name, any order).
        let patterns = [
            "<meta[^>]+(?:property|name)=[\"']\(property)[\"'][^>]+content=[\"']([^\"']+)[\"']",
            "<meta[^>]+content=[\"']([^\"']+)[\"'][^>]+(?:property|name)=[\"']\(property)[\"']",
        ]
        return patterns.lazy.compactMap { firstGroup(html, $0) }.first
    }

    private static func linkHref(_ html: String, rel: String) -> String? {
        firstGroup(html, "<link[^>]+rel=[\"'][^\"']*\(rel)[^\"']*[\"'][^>]+href=[\"']([^\"']+)[\"']")
            ?? firstGroup(html, "<link[^>]+href=[\"']([^\"']+)[\"'][^>]+rel=[\"'][^\"']*\(rel)[^\"']*[\"']")
    }

    private static func firstGroup(_ text: String, _ pattern: String) -> String? {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]),
              let m = re.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              m.numberOfRanges > 1, let r = Range(m.range(at: 1), in: text) else { return nil }
        return String(text[r])
    }

    private static func resolve(_ href: String, base: URL) -> URL? {
        if href.hasPrefix("//") { return URL(string: "https:\(href)") }
        return URL(string: href, relativeTo: base)?.absoluteURL
    }
}
