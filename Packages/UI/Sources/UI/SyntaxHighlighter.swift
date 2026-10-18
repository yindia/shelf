import SwiftUI

/// A tiny, language-agnostic syntax highlighter: colors comments, strings,
/// numbers, and a common keyword set via regex. Not a parser — good enough for
/// a preview card. Tune the palette constants here.
enum SyntaxHighlighter {
    private static let keywords: Set<String> = [
        "func", "def", "class", "struct", "enum", "import", "return", "if", "else",
        "for", "while", "let", "var", "const", "public", "private", "static", "void",
        "function", "async", "await", "new", "self", "this", "true", "false", "nil", "null",
        "guard", "switch", "case", "break", "continue", "throw", "try", "catch", "in",
    ]

    struct Palette {
        let base: Color
        let keyword: Color
        let string: Color
        let number: Color
        let comment: Color
    }

    static func palette(dark: Bool) -> Palette {
        dark
            ? Palette(base: Color(white: 0.90),
                      keyword: Color(hex: "#FF7AB2")!,
                      string: Color(hex: "#9DDC6D")!,
                      number: Color(hex: "#D0BF69")!,
                      comment: Color(white: 0.5))
            : Palette(base: Color(white: 0.15),
                      keyword: Color(hex: "#9B2393")!,
                      string: Color(hex: "#C41A16")!,
                      number: Color(hex: "#1C00CF")!,
                      comment: Color(white: 0.45))
    }

    static func highlight(_ code: String, dark: Bool) -> AttributedString {
        let palette = palette(dark: dark)
        var result = AttributedString(code)
        result.foregroundColor = palette.base

        apply(#"//[^\n]*|#[^\n]*"#, color: palette.comment, to: &result, in: code)
        apply(#""([^"\\]|\\.)*"|'([^'\\]|\\.)*'"#, color: palette.string, to: &result, in: code)
        apply(#"\b\d+(\.\d+)?\b"#, color: palette.number, to: &result, in: code)
        for keyword in keywords {
            apply("\\b\(keyword)\\b", color: palette.keyword, to: &result, in: code)
        }
        return result
    }

    private static func apply(_ pattern: String, color: Color, to attributed: inout AttributedString, in source: String) {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        let ns = source as NSString
        for match in regex.matches(in: source, range: NSRange(location: 0, length: ns.length)) {
            guard let range = Range(match.range, in: source),
                  let lower = AttributedString.Index(range.lowerBound, within: attributed),
                  let upper = AttributedString.Index(range.upperBound, within: attributed)
            else { continue }
            attributed[lower ..< upper].foregroundColor = color
        }
    }
}
