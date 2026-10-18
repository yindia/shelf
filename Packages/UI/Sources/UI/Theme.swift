import Core
import SwiftUI

/// All tunable visual + motion constants in one place. Adjust to taste against
/// the reference feel — nothing here is baked into view logic elsewhere.
public enum Theme {
    // MARK: Card geometry (8pt grid)
    /// Roomy enough for previews to breathe.
    public static let cardWidth: CGFloat = 280
    public static let cardHeight: CGFloat = 324
    /// HIG continuous corner radius for cards/panel.
    public static let cornerRadius: CGFloat = 13
    public static let cardSpacing: CGFloat = 16
    public static let headerHeight: CGFloat = 44
    public static let footerHeight: CGFloat = 28
    public static let bodyPadding: CGFloat = 16
    public static let headerPadding: CGFloat = 16

    // MARK: Panel
    public static let panelPadding: CGFloat = 24
    /// Gap between the tab bar and the card row.
    public static let cardsTopInset: CGFloat = 18
    /// Vertical breathing room below the card row (matches the top gap).
    public static let carouselVInset: CGFloat = 18
    /// Exactly fits: tab bar + divider + top gap + card row + bottom inset.
    public static var panelHeight: CGFloat { tabBarHeight + 1 + cardsTopInset + cardHeight + carouselVInset }
    /// Light, warm translucent bar so cards contrast and lift off it.
    public static let panelMaterial: NSVisualEffectView.Material = .popover
    /// Subtle warm wash over the vibrancy (cream in light, deep warm in dark).
    /// Low opacity so the desktop blur stays visible — just adds warmth.
    public static let barWarmTint = Color(nsColor: NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        return isDark ? NSColor(calibratedRed: 0.22, green: 0.18, blue: 0.14, alpha: 1)
                      : NSColor(calibratedRed: 0.99, green: 0.96, blue: 0.91, alpha: 1)
    })
    public static let barWarmTintOpacity: Double = 0.3
    /// Opaque warm surface for the Reduce Transparency fallback (adaptive).
    public static let barSolid = Color(nsColor: NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        return isDark ? NSColor(calibratedRed: 0.15, green: 0.13, blue: 0.11, alpha: 1)
                      : NSColor(calibratedRed: 0.97, green: 0.95, blue: 0.91, alpha: 1)
    })

    // MARK: Card surface — an elevated surface that ADAPTS to appearance:
    // light → white, dark → a raised dark gray (lighter than the bar so it lifts).
    public static let cardBody = Color(nsColor: NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        return isDark ? NSColor(calibratedWhite: 0.17, alpha: 1) : .white
    })
    public static let cardBorder = Color(nsColor: .separatorColor)
    public static let cardBorderWidth: CGFloat = 1
    /// HIG continuous corner style helper.
    public static let cornerStyle: RoundedCornerStyle = .continuous

    /// Readable text/icon color on a saturated header band (black on light accents
    /// like yellow, white on dark ones) — keeps contrast per HIG.
    public static func onHeader(for color: Color) -> Color {
        guard let rgb = NSColor(color).usingColorSpace(.sRGB) else { return .white }
        let luminance = 0.299 * rgb.redComponent + 0.587 * rgb.greenComponent + 0.114 * rgb.blueComponent
        return luminance > 0.62 ? .black : .white
    }

    // MARK: Selection / motion (Apple-subtle)
    public static let selectedScale: CGFloat = 1.02
    public static let hoverScale: CGFloat = 1.01
    /// Neighbors stay full strength; selection reads via ring + lift, not dimming.
    public static let unselectedDim: Double = 1.0
    /// Accent cue: a thin left edge + an 8pt dot in the header.
    public static let accentEdgeWidth: CGFloat = 3
    public static let selectionRingWidth: CGFloat = 2

    // MARK: Layered shadows (HIG depth: one tight contact + one wide ambient).
    public struct ShadowLayer: Sendable {
        public let opacity: Double
        public let radius: CGFloat
        public let y: CGFloat
    }
    public static let contactShadowRest = ShadowLayer(opacity: 0.05, radius: 2, y: 1)
    public static let ambientShadowRest = ShadowLayer(opacity: 0.10, radius: 16, y: 4)
    public static let contactShadowSelected = ShadowLayer(opacity: 0.08, radius: 3, y: 2)
    public static let ambientShadowSelected = ShadowLayer(opacity: 0.16, radius: 22, y: 10)
    /// Low-opacity hairline inner border on every card.
    public static let innerBorderOpacity: Double = 0.06


    public static let springResponse: Double = 0.30
    public static let springDamping: Double = 0.75
    /// Enter transition (slide up + fade).
    public static let enterSlide: CGFloat = 24
    public static let enterDuration: Double = 0.28
    public static let panelFadeDuration: Double = 0.18

    public static var selectionSpring: Animation {
        .spring(response: springResponse, dampingFraction: springDamping)
    }

    // MARK: Typography — system Dynamic Type text styles (SF Pro).
    /// Quiet, uppercase kind label (metadata, not a banner title).
    public static let kindLabelFont: Font = .caption.weight(.semibold)
    public static let kindLabelTracking: CGFloat = 0.6
    public static let timeFont: Font = .caption2
    public static let timeOpacity: Double = 1.0
    public static let bodyFont: Font = .callout
    public static let monoFont: Font = .system(.callout, design: .monospaced)
    public static let codeFont: Font = .system(.footnote, design: .monospaced)
    public static let footerFont: Font = .caption2
    public static let linkTitleFont: Font = .headline
    public static let tabFont: Font = .subheadline

    // MARK: Semantic text colors
    public static let primaryText = Color(nsColor: .labelColor)
    public static let secondaryText = Color(nsColor: .secondaryLabelColor)
    public static let tertiaryText = Color(nsColor: .tertiaryLabelColor)
    /// Text drawn on the saturated collection header band.
    public static let onHeaderColor = Color.white

    /// A subtle vertical gradient of the accent for header bands (top lighter,
    /// bottom slightly deeper) — richer than a flat fill.
    public static func headerGradient(_ base: Color) -> LinearGradient {
        LinearGradient(
            colors: [base.opacity(1.0).lighten(0.06), base.darken(0.08)],
            startPoint: .top, endPoint: .bottom
        )
    }

    // MARK: Tab bar (8pt grid)
    public static let tabBarHeight: CGFloat = 44
    public static let tabDotSize: CGFloat = 8
    /// Gap between the color dot and the label.
    public static let tabDotGap: CGFloat = 8
    /// Gap between adjacent tabs.
    public static let tabGap: CGFloat = 22
    /// Gap between the bar's zones (search / tabs / controls).
    public static let tabSpacing: CGFloat = 8
    /// Active-tab pill corner radius.
    public static let tabCornerRadius: CGFloat = 6
    public static let tabSelectedBgOpacity: Double = 0.16
    /// Drop-target highlight when dragging a card onto a tab.
    public static let tabDropHighlightOpacity: Double = 0.34

    // MARK: Header / source icon
    public static let sourceIconSize: CGFloat = 24
    public static let sourceIconCorner: CGFloat = 6
    /// Inset of the app icon from the header's trailing edge.
    public static let sourceIconInset: CGFloat = 6

    // MARK: Chips (image dimensions, etc.)
    public static let chipFont: Font = .caption2
    public static let chipCorner: CGFloat = 5
    public static let chipBgOpacity: Double = 0.55
    public static let mapPreviewCorner: CGFloat = 8

    // MARK: Warm accent palette (our identity) — light/dark token per hue.
    /// A named warm accent with explicit light + dark hex, resolved adaptively.
    public struct Accent: Sendable {
        public let light: String
        public let dark: String
        public var color: Color { adaptive(lightHex: light, darkHex: dark) }
    }

    public static let warmRed    = Accent(light: "#D1485B", dark: "#E0697A")
    public static let warmOrange = Accent(light: "#D9792E", dark: "#E89450")
    public static let warmAmber  = Accent(light: "#C79A1E", dark: "#D9B23C")
    public static let warmGreen  = Accent(light: "#3E9E6B", dark: "#5BBE88")
    public static let warmBlue   = Accent(light: "#3E73B5", dark: "#5E92D0")
    public static let warmPurple = Accent(light: "#7B5EC0", dark: "#9A7ED6")
    public static let warmGray   = Accent(light: "#7C7A77", dark: "#9A9894")

    /// Palette used for generated monogram tiles (link fallback).
    public static let monogramPalette: [Accent] = [warmRed, warmOrange, warmAmber, warmGreen, warmBlue, warmPurple]

    /// Deterministic palette color for a seed string (e.g. a domain).
    public static func monogramColor(for seed: String) -> Color {
        guard !monogramPalette.isEmpty else { return warmGray.color }
        var hash = 5381
        for byte in seed.utf8 { hash = ((hash << 5) &+ hash) &+ Int(byte) }
        return monogramPalette[abs(hash) % monogramPalette.count].color
    }

    // MARK: Thumbnail / icon tile styling
    public static let thumbCorner: CGFloat = 12
    /// Max height of a contained preview thumbnail (link/video) — ~55% of body.
    public static let previewMaxHeight: CGFloat = 130
    public static let thumbInnerShadowOpacity: Double = 0.22
    public static let thumbInnerShadowRadius: CGFloat = 4

    /// Palette token for a content kind.
    public static func accentToken(for kind: ClipKind) -> Accent {
        switch kind {
        case .text, .richText: warmBlue
        case .html, .code, .color: warmPurple
        case .image: warmRed
        case .video: warmBlue
        case .audio: warmOrange
        case .link: warmGreen
        case .file: warmAmber
        case .unknown: warmGray
        }
    }

    /// Accent for a content kind, from the warm palette (adaptive light/dark).
    public static func accent(for kind: ClipKind) -> Color { accentToken(for: kind).color }

    // MARK: WCAG helpers
    /// WCAG relative luminance of sRGB components.
    static func relLuminance(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> CGFloat {
        func lin(_ v: CGFloat) -> CGFloat { v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
        return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
    }

    /// Darkens a color until white text clears the target contrast (luminance ceiling).
    static func wcagDarken(_ color: NSColor, maxLuminance: CGFloat) -> NSColor {
        guard let c = color.usingColorSpace(.sRGB) else { return color }
        var (r, g, b) = (c.redComponent, c.greenComponent, c.blueComponent)
        var i = 0
        while relLuminance(r, g, b) > maxLuminance, i < 24 {
            r *= 0.92; g *= 0.92; b *= 0.92; i += 1
        }
        return NSColor(srgbRed: r, green: g, blue: b, alpha: 1)
    }

    /// The header band fill, guaranteed to pass WCAG AA (≥4.5:1) with white text
    /// by darkening the accent; darker still under Increase Contrast. Adapts to
    /// light/dark. Collection color when non-default, else the kind accent.
    public static func headerBandColor(collection: Collection?, kind: ClipKind, increaseContrast: Bool) -> Color {
        let ceiling: CGFloat = increaseContrast ? 0.12 : 0.18
        return Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            let base: Color
            if let collection, !collection.isDefault, let hex = Color(hex: collection.colorHex) {
                base = isDark ? hex.lighten(0.08) : hex
            } else {
                let token = accentToken(for: kind)
                base = Color(hex: isDark ? token.dark : token.light) ?? .gray
            }
            return wcagDarken(NSColor(base), maxLuminance: ceiling)
        })
    }

    /// The header band color for a card: the collection's color (adaptive) when it
    /// belongs to a non-default collection, otherwise the content kind's accent.
    public static func headerColor(collection: Collection?, kind: ClipKind) -> Color {
        if let collection, !collection.isDefault {
            return adaptiveFromHex(collection.colorHex)
        }
        return accent(for: kind)
    }

    /// Wraps a stored (light) hex into an adaptive color, brightening it slightly
    /// in dark mode so saturated bands read well on the deep glass.
    public static func adaptiveFromHex(_ hex: String) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let base = Color(hex: hex) ?? .gray
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return NSColor(isDark ? base.lighten(0.08) : base)
        })
    }

    /// Resolves a light/dark hex pair into one appearance-tracking color.
    public static func adaptive(lightHex: String, darkHex: String) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return NSColor(Color(hex: isDark ? darkHex : lightHex) ?? .gray)
        })
    }

    /// SF Symbol per content kind (shown in the header, left).
    public static func icon(for kind: ClipKind) -> String {
        switch kind {
        case .text: "text.alignleft"
        case .richText: "textformat"
        case .html: "chevron.left.forwardslash.chevron.right"
        case .code: "chevron.left.forwardslash.chevron.right"
        case .image: "photo"
        case .video: "film"
        case .audio: "waveform"
        case .color: "paintpalette.fill"
        case .link: "link"
        case .file: "doc.fill"
        case .unknown: "questionmark"
        }
    }

    // Deep, slightly desaturated accents — premium in both light and dark.
    private static func fallbackHex(for kind: ClipKind) -> String {
        switch kind {
        case .text, .richText: "#3B6FB5"   // deep blue
        case .html, .code: "#6E57B0"       // deep violet
        case .image: "#C0506B"             // dusty rose
        case .video: "#4A6FA5"             // steel blue
        case .audio: "#C27A3E"             // burnt amber
        case .link: "#2F8F6B"              // deep teal-green
        case .color: "#6E57B0"
        case .file: "#B5793A"              // ochre
        case .unknown: "#6E7279"           // slate gray
        }
    }
}

extension Color {
    /// Lightens toward white by `amount` (0...1).
    func lighten(_ amount: Double) -> Color {
        guard let rgb = NSColor(self).usingColorSpace(.sRGB) else { return self }
        return Color(.sRGB,
                     red: min(1, rgb.redComponent + amount),
                     green: min(1, rgb.greenComponent + amount),
                     blue: min(1, rgb.blueComponent + amount),
                     opacity: 1)
    }
    /// Darkens toward black by `amount` (0...1).
    func darken(_ amount: Double) -> Color {
        guard let rgb = NSColor(self).usingColorSpace(.sRGB) else { return self }
        return Color(.sRGB,
                     red: max(0, rgb.redComponent - amount),
                     green: max(0, rgb.greenComponent - amount),
                     blue: max(0, rgb.blueComponent - amount),
                     opacity: 1)
    }
}

public extension Color {
    /// Parses `#RRGGBB` / `#RRGGBBAA` hex. Returns nil on malformed input.
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6 || s.count == 8, let value = UInt64(s, radix: 16) else { return nil }
        let r, g, b, a: Double
        if s.count == 6 {
            r = Double((value >> 16) & 0xFF) / 255
            g = Double((value >> 8) & 0xFF) / 255
            b = Double(value & 0xFF) / 255
            a = 1
        } else {
            r = Double((value >> 24) & 0xFF) / 255
            g = Double((value >> 16) & 0xFF) / 255
            b = Double((value >> 8) & 0xFF) / 255
            a = Double(value & 0xFF) / 255
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}
