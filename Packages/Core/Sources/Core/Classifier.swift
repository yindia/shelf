import Foundation

/// Classifies a set of raw representations into a single `ClipKind`.
///
/// Order matters: richer/more-specific kinds win over plain text so that, e.g.,
/// an image copied with a text fallback is stored as `.image`.
public struct Classifier: Sendable {
    /// Bundle ids treated as developer tools — their text copies lean toward `.code`.
    public var developerBundleIDs: Set<String>

    public init(developerBundleIDs: Set<String> = Classifier.defaultDeveloperBundleIDs) {
        self.developerBundleIDs = developerBundleIDs
    }

    public static let defaultDeveloperBundleIDs: Set<String> = [
        "com.apple.dt.Xcode",
        "com.microsoft.VSCode",
        "com.microsoft.VSCodeInsiders",
        "com.sublimetext.4",
        "com.jetbrains.intellij",
        "com.googlecode.iterm2",
        "com.apple.Terminal",
        "dev.zed.Zed",
    ]

    public func classify(_ reps: [CapturedRepresentation], sourceBundleID: String? = nil) -> ClipKind {
        let types = Set(reps.map(\.typeIdentifier))

        if types.contains(UTIs.color) { return .color }
        if types.contains(UTIs.png) || types.contains(UTIs.tiff) || types.contains(UTIs.jpeg) {
            return .image
        }
        // Audio: an explicit audio UTI, or a file URL with an audio extension.
        if types.contains(where: { UTIs.audioTypeHints.contains($0) }) { return .audio }
        if types.contains(UTIs.fileURL), let ext = fileExtension(in: reps) {
            if UTIs.audioExtensions.contains(ext) { return .audio }
            if UTIs.videoExtensions.contains(ext) { return .video }
        }
        // File URL that isn't an image/audio/video.
        if types.contains(UTIs.fileURL) { return .file }
        if types.contains(UTIs.html) { return .html }
        if types.contains(UTIs.rtf) { return .richText }

        if let text = plainText(in: reps) {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if Classifier.looksLikeHexColor(trimmed) { return .color }
            if looksLikeURL(text) || MapLink.isMap(URL(string: trimmed)) { return .link }
            let fromDevApp = sourceBundleID.map(developerBundleIDs.contains) ?? false
            if looksLikeCode(text, fromDeveloperApp: fromDevApp) { return .code }
            return .text
        }
        return .unknown
    }

    /// Lowercased path extension of a `public.file-url` representation, if any.
    private func fileExtension(in reps: [CapturedRepresentation]) -> String? {
        guard let rep = reps.first(where: { $0.typeIdentifier == UTIs.fileURL }),
              let s = String(data: rep.data, encoding: .utf8),
              let url = URL(string: s.trimmingCharacters(in: .whitespacesAndNewlines))
        else { return nil }
        let ext = url.pathExtension.lowercased()
        return ext.isEmpty ? nil : ext
    }

    private func plainText(in reps: [CapturedRepresentation]) -> String? {
        for uti in [UTIs.utf8PlainText, UTIs.plainText, UTIs.text, UTIs.url] {
            if let rep = reps.first(where: { $0.typeIdentifier == uti }),
               let s = String(data: rep.data, encoding: .utf8) {
                return s
            }
        }
        return nil
    }

    /// A bare hex color like `#F5AB82`, `F5AB82`, `#FFF`, or `#RRGGBBAA`.
    public static func looksLikeHexColor(_ s: String) -> Bool {
        let hex = s.hasPrefix("#") ? String(s.dropFirst()) : s
        guard [3, 6, 8].contains(hex.count) else { return false }
        return hex.allSatisfy { $0.isHexDigit }
    }

    /// Single-token string that parses as an http(s) URL.
    func looksLikeURL(_ string: String) -> Bool {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains(where: \.isWhitespace) else { return false }
        guard let url = URL(string: trimmed), let scheme = url.scheme?.lowercased() else {
            return false
        }
        return (scheme == "http" || scheme == "https") && url.host != nil
    }

    /// Heuristic code detection: a score over common syntax signals. A copy from a
    /// known developer app clears the bar with a lower score.
    func looksLikeCode(_ string: String, fromDeveloperApp: Bool) -> Bool {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 6 else { return false }

        var score = 0
        let keywords = ["func ", "def ", "class ", "import ", "const ", "let ", "var ",
                        "return ", "public ", "private ", "void ", "function ", "=>", "#include",
                        "struct ", "enum ", "async ", "await ", "println", "console.log"]
        if keywords.contains(where: trimmed.contains) { score += 2 }

        let symbols = CharacterSet(charactersIn: "{}();[]<>")
        let symbolCount = trimmed.unicodeScalars.filter(symbols.contains).count
        if symbolCount >= 3 { score += 2 }
        if trimmed.contains(";\n") || trimmed.contains(") {") || trimmed.contains("();") { score += 1 }
        if trimmed.contains("    ") || trimmed.contains("\t") { score += 1 }  // indentation

        return fromDeveloperApp ? score >= 2 : score >= 4
    }
}
