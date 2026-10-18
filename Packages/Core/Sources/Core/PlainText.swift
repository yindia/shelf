import Foundation

/// Strips formatting from a set of representations, yielding plain text only.
/// Used by "paste without formatting" (Option on paste).
public enum PlainText {
    /// The best plain-text string across the common text UTIs, or a stripped
    /// rendering of RTF/HTML as a last resort.
    public static func string(from reps: [CapturedRepresentation]) -> String? {
        for uti in [UTIs.utf8PlainText, UTIs.plainText, UTIs.text, UTIs.url] {
            if let rep = reps.first(where: { $0.typeIdentifier == uti }),
               let s = String(data: rep.data, encoding: .utf8) {
                return s
            }
        }
        return nil
    }

    /// Returns a single UTF-8 plain-text representation (formatting removed).
    /// If no text is present, returns the original reps unchanged.
    public static func strip(_ reps: [CapturedRepresentation]) -> [CapturedRepresentation] {
        guard let text = string(from: reps) else { return reps }
        return [CapturedRepresentation(typeIdentifier: UTIs.utf8PlainText, data: Data(text.utf8))]
    }
}
