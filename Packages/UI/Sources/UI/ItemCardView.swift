import Core
import SwiftUI

/// A single preview card in the modern iOS/Apple idiom: a neutral elevated
/// surface, continuous corners, SF text styles, and color expressed only as a
/// small tinted icon tile (like iOS Settings rows) — no saturated header band.
struct ItemCardView: View {
    let item: ClipItemModel
    let index: Int
    let isSelected: Bool
    /// Per-item accent (collection color, else kind accent). Tints the icon tile.
    let headerColor: Color
    /// Unused since the saturated band was removed; kept for call-site stability.
    let headerBand: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @EnvironmentObject private var loader: MediaPreviewLoader
    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 0) {
            header
            CardContentView(item: item)
                // minHeight 0 lets a fill-preview (e.g. a wide link image) shrink
                // instead of imposing a minimum that overflows the fixed card and
                // clips the header/footer.
                .frame(maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                // Media previews bleed to the card edges (Paste reference);
                // text-like kinds keep reading padding.
                .padding(isFullBleed ? 0 : Theme.bodyPadding)
                .clipped()
            footer
        }
        // Neutral elevated surface (adapts light/dark).
        .background(Theme.cardBody)
        .frame(width: Theme.cardWidth, height: Theme.cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: Theme.cornerStyle))
        // Hairline separator border for definition on any background (iOS-style).
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius, style: Theme.cornerStyle)
                .strokeBorder(Color.primary.opacity(Theme.hairlineOpacity), lineWidth: 1)
        )
        // Selection: a system-accent ring over the hairline.
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius, style: Theme.cornerStyle)
                .strokeBorder(
                    isSelected ? Color.accentColor : .clear,
                    lineWidth: isSelected ? Theme.selectionRingWidth : 0
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

    /// Media kinds whose preview fills the body edge-to-edge (reference style).
    private var isFullBleed: Bool {
        switch item.kind {
        case .image, .link, .video, .file, .color: return true
        default: return false
        }
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

    // MARK: Header — saturated per-kind band (Paste reference): white kind label
    // + time on the left, source app icon in a white tile on the right.

    private var header: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(headerTitle)
                    .font(.headline)
                    .lineLimit(1)
                Text(Self.relativeTime.localizedString(for: item.createdAt, relativeTo: Date()))
                    .font(.subheadline)
                    .opacity(0.9)
            }
            Spacer(minLength: 6)
            if item.isPinned {
                Image(systemName: "pin.fill").font(.footnote)
            }
            sourceBadge
        }
        .foregroundStyle(.white)
        .padding(.horizontal, Theme.headerPadding)
        .frame(height: Theme.headerHeight)
        .frame(maxWidth: .infinity)
        .background(Theme.headerGradient(headerBand))
    }

    /// App icon on a white rounded tile (reference top-right badge); falls back
    /// to the kind glyph tinted with the header color.
    private var sourceBadge: some View {
        RoundedRectangle(cornerRadius: Theme.sourceTileCorner, style: .continuous)
            .fill(.white)
            .frame(width: Theme.sourceTileSize, height: Theme.sourceTileSize)
            .overlay {
                if let image = SourceAppIcon.image(for: item.sourceBundleID) {
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.high)
                        .antialiased(true)
                        .frame(width: Theme.sourceIconSize, height: Theme.sourceIconSize)
                } else {
                    Image(systemName: Theme.icon(for: item.kind))
                        .font(.system(size: Theme.sourceIconSize * 0.6, weight: .semibold))
                        .foregroundStyle(headerColor)
                }
            }
            .shadow(color: .black.opacity(0.12), radius: 1, y: 0.5)
            .accessibilityHidden(true)
    }

    // MARK: Footer

    @ViewBuilder private var footer: some View {
        if item.kind == .image {
            EmptyView()   // full-bleed photo with its own W×H chip
        } else if let title = footerTitle {
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
            // Reference: a single centered metadata line (e.g. "175 characters").
            Text(CardMeta.footer(for: item))
                .font(Theme.footerFont)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, Theme.bodyPadding)
                .frame(height: Theme.footerHeight)
        }
    }

    /// Header title: a user-given name wins (named snippets/templates), else the
    /// content kind (reference shows both cases).
    private var headerTitle: String {
        if let name = item.userTitle, !name.isEmpty { return name }
        if let smart = loader.smartSummary(for: item)?.title, !smart.isEmpty { return smart }
        return item.kind.rawValue.capitalized
    }

    /// Footer title: the fetched page title for links (Paste-style), else the
    /// generic per-kind title.
    private var footerTitle: String? {
        if item.kind == .link, !item.isMapLink, let t = loader.linkTitle(for: item), !t.isEmpty {
            return t
        }
        return CardMeta.title(for: item)
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
