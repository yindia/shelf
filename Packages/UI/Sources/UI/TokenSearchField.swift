import Core
import SwiftUI

/// Power Search field: inline filter tokens (app / content type / date /
/// pinboard) followed by a text cursor, with an autocomplete dropdown that
/// suggests filters as you type. Mirrors the Paste reference.
struct TokenSearchField: View {
    @Binding var text: String
    var placeholder: String = "Search"
    let tokens: [SearchToken]
    let suggestions: [SearchToken]
    let onApply: (SearchToken) -> Void
    let onRemove: (SearchToken) -> Void
    let onRemoveLast: () -> Void
    var onClose: (() -> Void)?

    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 6) {
            field
        }
        .overlay(alignment: .topLeading) {
            if !suggestions.isEmpty {
                dropdown.offset(y: 44)
            }
        }
    }

    private var field: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            ForEach(tokens) { token in chip(token) }
            TextField(tokens.isEmpty ? placeholder : "", text: $text)
                .textFieldStyle(.plain)
                .font(Theme.bodyFont)
                .focused($focused)
                .onKeyPress(.delete) {
                    if text.isEmpty { onRemoveLast(); return .handled }
                    return .ignored
                }
                .onKeyPress(.return) {
                    if let first = suggestions.first { onApply(first); return .handled }
                    return .ignored
                }
            if let onClose {
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close search")
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(Capsule().fill(Color(nsColor: .textBackgroundColor)))
        .overlay(Capsule().strokeBorder(Color.accentColor.opacity(focused ? 0.9 : 0), lineWidth: 2.5))
        .onAppear { focused = true }
    }

    private func chip(_ token: SearchToken) -> some View {
        HStack(spacing: 4) {
            icon(token).frame(width: 15, height: 15)
            Text(token.label).font(Theme.footerFont.weight(.medium)).lineLimit(1)
        }
        .foregroundStyle(.primary)
        .padding(.leading, 5).padding(.trailing, 7).padding(.vertical, 3)
        .background(Capsule().fill(.primary.opacity(0.1)))
        .onTapGesture { onRemove(token) }
        .help("Remove filter")
    }

    private var dropdown: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(suggestions) { token in
                Button { onApply(token) } label: {
                    HStack(spacing: 10) {
                        icon(token).frame(width: 18, height: 18)
                        Text(token.label).font(Theme.bodyFont).foregroundStyle(.primary)
                        Spacer()
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: 280, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.primary.opacity(0.08)))
        .shadow(color: .black.opacity(0.18), radius: 16, y: 8)
        .padding(.leading, 28)
        .zIndex(10)
    }

    /// Token icon: app icon image for apps, SF symbols for the rest.
    @ViewBuilder private func icon(_ token: SearchToken) -> some View {
        switch token {
        case .app(let bundleID, _):
            if let image = SourceAppIcon.image(for: bundleID) {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "app").resizable().foregroundStyle(.secondary)
            }
        case .kind(let k):
            Image(systemName: Theme.icon(for: k)).resizable().aspectRatio(contentMode: .fit)
                .foregroundStyle(.secondary)
        case .date:
            Image(systemName: "calendar").resizable().aspectRatio(contentMode: .fit)
                .foregroundStyle(.secondary)
        case .pinboard(let id, _):
            Circle().fill(pinboardColor(id))
        }
    }

    private func pinboardColor(_ id: UUID) -> Color { .secondary }
}
