import Core
import SwiftUI

/// Top bar (HIG), true three-zone layout that never collides: leading search
/// (fixed), centered collection tabs (flexible; scrolls when they overflow),
/// trailing new/overflow (fixed). Tabs are drop targets for refiling cards.
struct CollectionTabBar: View {
    let collections: [Collection]
    let selectedID: UUID?
    let isSearching: Bool
    @Binding var searchText: String
    let onSelect: (UUID) -> Void
    let onToggleSearch: () -> Void
    let onAdd: () -> Void
    /// Drag-and-drop refile: (itemID, destination collectionID).
    let onMove: (UUID, UUID) -> Void
    var onDelete: (UUID) -> Void = { _ in }

    @FocusState private var searchFocused: Bool
    @Environment(\.colorSchemeContrast) private var contrast
    @State private var dropTargetID: UUID?

    var body: some View {
        HStack(spacing: Theme.tabSpacing) {
            searchControl
                .fixedSize()

            if isSearching {
                Spacer(minLength: 0)
            } else {
                // Left-aligned tabs (scroll if they overflow) + inline "+".
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.tabGap) {
                        ForEach(collections) { tab($0) }
                        iconButton("plus", help: "New Collection", action: onAdd)
                    }
                    .frame(maxHeight: .infinity)
                }
                .scrollClipDisabled()
                Spacer(minLength: 8)
            }
        }
        .frame(height: Theme.tabBarHeight)
        .padding(.horizontal, Theme.panelPadding)
    }

    private var searchControl: some View {
        Group {
            if isSearching {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").foregroundStyle(Theme.secondaryText)
                    TextField("Search", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(Theme.bodyFont)
                        .focused($searchFocused)
                        .frame(width: 180)
                    Button { onToggleSearch() } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.secondaryText)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close search")
                }
                .padding(.horizontal, 8).padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: Theme.tabCornerRadius, style: .continuous)
                    .fill(Color(nsColor: .textBackgroundColor)))
                .onAppear { searchFocused = true }
            } else {
                iconButton("magnifyingglass", help: "Search", action: onToggleSearch)
            }
        }
    }

    // MARK: Tab (selectable + drop target)

    private func tab(_ collection: Collection) -> some View {
        let isSelected = collection.id == selectedID
        let isDropTarget = collection.id == dropTargetID
        let color = Color(hex: collection.colorHex) ?? .gray
        return Button {
            onSelect(collection.id)
        } label: {
            HStack(spacing: Theme.tabDotGap) {
                // Active tab shows the collection's SF icon; others show a dot.
                if isSelected {
                    Image(systemName: collection.iconSymbol)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(color)
                } else {
                    Circle()
                        .fill(color)
                        .frame(width: Theme.tabDotSize, height: Theme.tabDotSize)
                        .overlay(contrast == .increased
                            ? Circle().strokeBorder(Theme.primaryText.opacity(0.5), lineWidth: 1) : nil)
                }
                Text(collection.name)
                    .font(.subheadline.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Theme.primaryText : Theme.secondaryText)
                    .fixedSize()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background {
                // Active tab: a .regularMaterial pill. Drop target: accent tint.
                let shape = RoundedRectangle(cornerRadius: Theme.tabCornerRadius, style: .continuous)
                if isDropTarget {
                    shape.fill(color.opacity(Theme.tabDropHighlightOpacity))
                } else if isSelected {
                    shape.fill(.regularMaterial)
                }
            }
            .overlay(RoundedRectangle(cornerRadius: Theme.tabCornerRadius, style: .continuous)
                .strokeBorder(color.opacity(isDropTarget ? 0.9 : 0), lineWidth: isDropTarget ? 1.5 : 0))
            .scaleEffect(isDropTarget ? 1.06 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isDropTarget)
        .contextMenu {
            if !collection.isDefault {
                Button("Delete Collection", role: .destructive) { onDelete(collection.id) }
            }
        }
        .dropDestination(for: String.self) { ids, _ in
            guard let first = ids.first, let itemID = UUID(uuidString: first) else { return false }
            onMove(itemID, collection.id)
            return true
        } isTargeted: { targeted in
            dropTargetID = targeted ? collection.id : (dropTargetID == collection.id ? nil : dropTargetID)
        }
        .accessibilityLabel(collection.name)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private func iconButton(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.secondaryText)
                .frame(width: 28, height: 28)
                .background(RoundedRectangle(cornerRadius: Theme.tabCornerRadius, style: .continuous)
                    .fill(Theme.primaryText.opacity(0.06)))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
    }
}
