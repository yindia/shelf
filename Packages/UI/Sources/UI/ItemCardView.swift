import Core
import SwiftUI

/// A single preview card, styled to the macOS HIG: SF Pro text styles, semantic
/// colors, continuous corners, system vibrancy-friendly surfaces. Header band
/// color comes from the item's collection; the kind selects icon + content body.
struct ItemCardView: View {
    let item: ClipItemModel
    let index: Int
    let isSelected: Bool
    /// Collection/kind accent.
    let headerColor: Color
    /// AA-darkened band fill so white header text passes contrast.
    let headerBand: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 0) {
            header
            CardContentView(item: item)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(item.kind == .image ? 0 : Theme.bodyPadding)
                .clipped()
            footer
        }
        // White/elevated body surface (adapts light/dark).
        .background(Theme.cardBody)
        .frame(width: Theme.cardWidth, height: Theme.cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: Theme.cornerStyle))
        // Selection: a system-accent ring (like the reference's blue outline).
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius, style: Theme.cornerStyle)
                .strokeBorder(
                    isSelected ? Color.accentColor : (contrast == .increased ? Theme.cardBorder : .clear),
                    lineWidth: isSelected ? Theme.selectionRingWidth : (contrast == .increased ? 1 : 0)
                )
        )
        // Single soft ambient shadow + a faint contact shadow.
        .shadow(color: .black.opacity(contactShadow.opacity), radius: contactShadow.radius, y: contactShadow.y)
        .shadow(color: .black.opacity(ambientShadow.opacity), radius: ambientShadow.radius, y: ambientShadow.y)
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

    // MARK: Header — neutral; color is only a small dot cue.

    private var header: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(item.kind.rawValue.capitalized)
                    .font(.subheadline.weight(.semibold))
                Text(Self.relativeTime.localizedString(for: item.createdAt, relativeTo: Date()))
                    .font(.caption)
                    .opacity(0.85)
            }
            Spacer()
            if item.isPinned {
                Image(systemName: "pin.fill").font(.caption2).opacity(0.9)
            }
            sourceBadge
        }
        .foregroundStyle(.white)
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

    @ViewBuilder private var footer: some View {
        if item.kind == .image {
            EmptyView()   // full-bleed photo with its own W×H chip
        } else if let title = CardMeta.title(for: item) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary).lineLimit(1)
                if let sub = CardMeta.subtitle(for: item) {
                    Text(sub).font(Theme.footerFont)
                        .foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Theme.bodyPadding)
            .padding(.vertical, 8)
        } else {
            HStack {
                Text(CardMeta.footer(for: item))
                    .font(Theme.footerFont).foregroundStyle(.secondary).lineLimit(1)
                Spacer()
                Text("⌘\(index + 1)").font(Theme.footerFont).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, Theme.bodyPadding)
            .frame(height: Theme.footerHeight)
            .frame(maxWidth: .infinity)
        }
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
