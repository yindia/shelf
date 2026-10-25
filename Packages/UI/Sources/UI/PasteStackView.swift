import Core
import SwiftUI

/// The floating Paste Stack window: a glass card listing queued items in paste
/// order, with a close button, a direction toggle, and per-row removal.
public struct PasteStackView: View {
    @ObservedObject private var stack: PasteStackModel
    let onClose: () -> Void

    public init(stack: PasteStackModel, onClose: @escaping () -> Void) {
        self.stack = stack
        self.onClose = onClose
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.4)
            if stack.items.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .frame(width: 360)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(.primary.opacity(0.08), lineWidth: 1))
        .shadow(color: .black.opacity(0.22), radius: 24, y: 10)
    }

    private var header: some View {
        HStack {
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            Spacer()
            Text("Paste Stack").font(.headline)
            Spacer()
            Button { stack.toggleDirection() } label: {
                Image(systemName: stack.reversed ? "arrow.up.arrow.down.circle.fill" : "arrow.up.arrow.down")
                    .font(.title3)
                    .foregroundStyle(stack.reversed ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.plain)
            .help(stack.reversed ? "Pasting bottom-to-top" : "Pasting top-to-bottom")
        }
        .padding(.horizontal, 16)
        .frame(height: 48)
    }

    private var list: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(stack.items.enumerated()), id: \.element.id) { index, item in
                    row(item)
                    if index < stack.items.count - 1 {
                        Divider().opacity(0.3).padding(.leading, 44)
                    }
                }
            }
        }
        .frame(maxHeight: 320)
    }

    private func row(_ item: ClipItemModel) -> some View {
        HStack(spacing: 10) {
            Image(systemName: Theme.icon(for: item.kind))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            Text(rowLabel(item))
                .font(.body)
                .foregroundStyle(.primary)
                .lineLimit(2)
            Spacer(minLength: 6)
            Button { stack.remove(item.id) } label: {
                Image(systemName: "minus.circle.fill").foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Remove from stack")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private var emptyState: some View {
        Text("Copy items to add them to the stack")
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
    }

    private func rowLabel(_ item: ClipItemModel) -> String {
        if let title = item.userTitle, !title.isEmpty { return title }
        if let text = item.plainText?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
            return text
        }
        if item.kind == .link, let host = item.linkURL?.host { return host }
        return item.kind.rawValue.capitalized
    }
}
