import AppKit
import Core
import SwiftUI

/// Spotlight/Raycast-style search surface: a large field over a live results
/// list, on blurred glass. Keyboard handling is done by the window controller.
public struct SpotlightSearchView: View {
    @ObservedObject private var model: SpotlightViewModel
    @FocusState private var focused: Bool
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    public init(model: SpotlightViewModel) { self.model = model }

    public var body: some View {
        VStack(spacing: 0) {
            field.zIndex(1)   // keep the autocomplete dropdown above the results list
            if !model.results.isEmpty {
                Divider().opacity(0.5)
                list
            }
        }
        .background {
            if reduceTransparency { Color(nsColor: .windowBackgroundColor) }
            else { VisualEffectView(material: Theme.spotlightMaterial, blendingMode: .behindWindow) }
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.spotlightCorner, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.spotlightCorner, style: .continuous)
            .strokeBorder(.white.opacity(0.08), lineWidth: 1))
        .frame(width: Theme.spotlightWidth)
    }

    private var field: some View {
        TokenSearchField(
            text: $model.searchText,
            placeholder: "Search your clipboard…",
            tokens: model.activeSearchTokens,
            suggestions: model.searchSuggestions,
            onApply: { model.applyToken($0) },
            onRemove: { model.removeToken($0) },
            onRemoveLast: { model.removeLastToken() }
        )
        .onChange(of: model.searchText) { _, _ in model.onSearchChanged() }
        .padding(.horizontal, 16)
        .frame(minHeight: Theme.spotlightFieldHeight)
    }

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(model.results.enumerated()), id: \.element.id) { index, item in
                        SpotlightRow(item: item, dot: model.color(for: item.listID),
                                     selected: index == model.selectedIndex)
                            .id(index)
                            .contentShape(Rectangle())
                            .onTapGesture { model.selectedIndex = index; model.activateSelection() }
                    }
                }
            }
            .frame(height: CGFloat(min(model.results.count, Theme.spotlightMaxRows)) * Theme.spotlightRowHeight)
            .onChange(of: model.selectedIndex) { _, i in withAnimation(.easeOut(duration: 0.12)) { proxy.scrollTo(i) } }
        }
    }
}

/// One result row: type icon · preview · source app · collection dot.
struct SpotlightRow: View {
    let item: ClipItemModel
    let dot: Color?
    let selected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: Theme.icon(for: item.kind))
                .font(.body).foregroundStyle(selected ? Color.white : Theme.accent(for: item.kind))
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(preview).font(.body).lineLimit(1)
                    .foregroundStyle(selected ? .white : .primary)
                Text(subtitle).font(.caption).lineLimit(1)
                    .foregroundStyle(selected ? Color.white.opacity(0.8) : .secondary)
            }
            Spacer(minLength: 8)
            if let dot { Circle().fill(dot).frame(width: 8, height: 8) }
            if let icon = SourceAppIcon.image(for: item.sourceBundleID) {
                Image(nsImage: icon).resizable().frame(width: 18, height: 18)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            }
        }
        .padding(.horizontal, 16)
        .frame(height: Theme.spotlightRowHeight)
        .background(selected ? Color.accentColor.opacity(0.9) : .clear)
    }

    private var preview: String {
        if let t = item.userTitle, !t.isEmpty { return t }
        if item.kind == .image { return item.ocrText.map { "Image · \($0)" } ?? "Image" }
        if item.kind == .link { return item.linkURL?.host ?? item.plainText ?? "Link" }
        return (item.plainText ?? CardMeta.footer(for: item)).replacingOccurrences(of: "\n", with: " ")
    }

    private var subtitle: String {
        let app = SourceAppIcon.name(for: item.sourceBundleID)
        let kind = item.kind.rawValue.capitalized
        return [kind, app].compactMap { $0 }.joined(separator: " · ")
    }
}
