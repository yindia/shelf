import Core
import SwiftUI

/// A single preview card, styled to the macOS HIG: SF Pro text styles, semantic
/// colors, continuous corners, system vibrancy-friendly surfaces. Header band
/// color comes from the item's collection; the kind selects icon + content body.
struct ItemCardView: View {
    let item: ClipItemModel
    let index: Int
    let isSelected: Bool
    /// Vivid accent (selection ring + glow).
    let headerColor: Color
    /// AA-guaranteed band fill (darkened so white text passes contrast).
    let headerBand: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 0) {
            header
            VStack(spacing: 0) {
                CardContentView(item: item)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(Theme.bodyPadding)
                    .clipped()
                footer
            }
        }
        .frame(width: Theme.cardWidth, height: Theme.cardHeight)
        // Translucent elevated surface (tracks light/dark); solid under Reduce
        // Transparency. Depth from shadow, not strokes.
        .background(reduceTransparency ? AnyShapeStyle(Theme.cardBody) : AnyShapeStyle(.regularMaterial))
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: Theme.cornerStyle))
        // Glass halo behind the selected card, tinted with its accent.
        .background(alignment: .center) {
            if isSelected {
                SelectionHalo(tint: headerColor)
                    .padding(Theme.selectionHaloInset)
            }
        }
        // Accent ring only on the selected card (and a hairline only for
        // Increased Contrast, per accessibility).
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius, style: Theme.cornerStyle)
                .strokeBorder(
                    isSelected ? headerColor : (contrast == .increased ? Theme.cardBorder : .clear),
                    lineWidth: isSelected ? Theme.selectionRingWidth : (contrast == .increased ? 1 : 0)
                )
        )
        // Layered shadows: tight contact + wide ambient.
        .shadow(color: .black.opacity(contactShadow.opacity), radius: contactShadow.radius, y: contactShadow.y)
        .shadow(color: .black.opacity(ambientShadow.opacity), radius: ambientShadow.radius, y: ambientShadow.y)
        // Accent glow on selection.
        .shadow(color: isSelected ? headerColor.opacity(Theme.selectionGlowOpacity) : .clear,
                radius: isSelected ? Theme.selectionGlowRadius : 0)
        .scaleEffect(reduceMotion ? 1 : scale)
        .opacity(opacity)
        .animation(reduceMotion ? .none : Theme.selectionSpring, value: isSelected)
        .animation(reduceMotion ? .none : Theme.selectionSpring, value: isHovering)
        .onHover { isHovering = $0 }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint("Press Return or double-click to paste. Command-\(index + 1) also pastes.")
    }

    private var scale: CGFloat {
        if isSelected { return Theme.selectedScale }
        if isHovering { return Theme.hoverScale }
        return 1
    }

    private var contactShadow: Theme.ShadowLayer { isSelected ? Theme.contactShadowSelected : Theme.contactShadowRest }
    private var ambientShadow: Theme.ShadowLayer { isSelected ? Theme.ambientShadowSelected : Theme.ambientShadowRest }

    /// Dimming neighbors is a visual cue; keep full opacity under Reduce Transparency.
    private var opacity: Double {
        if isSelected || reduceTransparency { return 1 }
        return Theme.unselectedDim
    }

    // MARK: Header band (collection color)

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: Theme.icon(for: item.kind))
                .font(.subheadline.weight(.bold))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                Text(item.kind.rawValue.capitalized)
                    .font(Theme.kindLabelFont)
                Text(Self.relativeTime.localizedString(for: item.createdAt, relativeTo: Date()))
                    .font(Theme.timeFont)
                    .opacity(Theme.timeOpacity)
            }
            Spacer()
            sourceBadge
        }
        .foregroundStyle(Theme.onHeaderColor)
        // Subtle shadow as belt-and-suspenders legibility insurance.
        .shadow(color: .black.opacity(0.35), radius: 1, y: 0.5)
        .padding(.leading, Theme.headerPadding)
        .padding(.trailing, Theme.sourceIconInset)
        .frame(height: Theme.headerHeight)
        .frame(maxWidth: .infinity)
        .background(Theme.headerGradient(headerBand))
    }

    private var sourceBadge: some View {
        Group {
            if let image = SourceAppIcon.image(for: item.sourceBundleID) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
                    .frame(width: Theme.sourceIconSize, height: Theme.sourceIconSize)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.sourceIconCorner, style: .continuous))
            } else {
                Image(systemName: Theme.icon(for: item.kind))
                    .font(.caption)
                    .opacity(0.9)
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: Footer

    private var footer: some View {
        HStack {
            Text(CardMeta.footer(for: item))
                .font(Theme.footerFont)
                .foregroundStyle(Theme.secondaryText)   // AA on the body surface
                .lineLimit(1)
            Spacer()
            Text("⌘\(index + 1)")
                .font(Theme.footerFont)
                .foregroundStyle(Theme.secondaryText)
        }
        .padding(.horizontal, Theme.bodyPadding)   // footer inset matches body side insets
        .frame(height: Theme.footerHeight)
        .frame(maxWidth: .infinity)
    }

    /// e.g. "Text, copied 11 minutes ago from Safari. example.com…"
    private var accessibilityText: String {
        let kindName = item.kind.rawValue.capitalized
        let when = Self.relativeTime.localizedString(for: item.createdAt, relativeTo: Date())
        let app = SourceAppIcon.name(for: item.sourceBundleID)
        let fromApp = app.map { " from \($0)" } ?? ""
        let preview = (item.plainText?.trimmingCharacters(in: .whitespacesAndNewlines))
            .map { String($0.prefix(80)) } ?? CardMeta.footer(for: item)
        return "\(kindName), copied \(when)\(fromApp). \(preview)"
    }

    private static let relativeTime: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()
}
