import Core
import SwiftUI

/// The panel root: system vibrancy bar · collection tab bar · card carousel.
/// Honors Reduce Transparency (opaque fallback) and Reduce Motion.
public struct PanelView: View {
    @ObservedObject private var model: PanelViewModel
    @ObservedObject private var previewLoader: MediaPreviewLoader
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast
    @State private var pendingDelete: ClipItemModel?

    public init(model: PanelViewModel, previewLoader: MediaPreviewLoader) {
        self.model = model
        self.previewLoader = previewLoader
    }

    public var body: some View {
        ZStack {
            GlassSurface()

            VStack(spacing: 0) {
                CollectionTabBar(
                    collections: model.collections,
                    selectedID: model.selectedCollectionID,
                    isSearching: model.isSearching,
                    searchText: $model.searchText,
                    onSelect: { model.selectCollection($0) },
                    onToggleSearch: { model.toggleSearch() },
                    onAdd: { model.beginCreateCollection() },
                    onMove: { model.move(itemID: $0, to: $1) },
                    onEditRules: { model.beginEditRules() }
                )
                Divider().opacity(0.5)
                // Rebuild the content subtree on each collection change so no
                // stale cards survive; swap is instant (no cross-fade).
                content
                    .id(model.selectedCollectionID)
                    .transaction { $0.animation = nil }
            }
        }
        .frame(height: Theme.panelHeight)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: Theme.cornerStyle))
        .environmentObject(previewLoader)
        .sheet(isPresented: $model.isCreatingCollection) {
            NewCollectionSheet(onCreate: model.createCollection, onCancel: { model.isCreatingCollection = false })
        }
        .sheet(isPresented: $model.isEditingRules) {
            AutoCategorizationSettingsView(
                rules: model.autoRules,
                collections: model.collections,
                onCommit: { model.commitRules($0) },
                onClose: { model.isEditingRules = false }
            )
        }
        .confirmationDialog(
            "Delete this item?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            presenting: pendingDelete
        ) { item in
            Button("Delete", role: .destructive) { model.delete(item); pendingDelete = nil }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: { _ in
            Text("This permanently removes the clip and its contents.")
        }
    }

    @ViewBuilder private var content: some View {
        if model.visibleItems.isEmpty {
            emptyState
        } else {
            carousel
        }
    }

    private var carousel: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.cardSpacing) {
                    ForEach(Array(model.visibleItems.enumerated()), id: \.element.id) { index, item in
                        ItemCardView(
                            item: item,
                            index: index,
                            isSelected: index == model.selectedIndex,
                            headerColor: Theme.headerColor(collection: model.color(for: item.listID), kind: item.kind),
                            headerBand: Theme.headerBandColor(collection: model.color(for: item.listID), kind: item.kind, increaseContrast: contrast == .increased)
                        )
                        .id(index)
                        .draggable(item.id.uuidString)
                        .onTapGesture(count: 2) { model.activate(index: index) }
                        .onTapGesture { model.selectIndex(index) }
                        .transition(reduceMotion
                            ? .opacity
                            : .asymmetric(
                                insertion: .offset(y: Theme.enterSlide).combined(with: .opacity),
                                removal: .opacity))
                    }
                }
                .padding(.horizontal, Theme.panelPadding)
                .padding(.top, Theme.cardsTopInset)
                .padding(.bottom, Theme.carouselVInset)
            }
            .animation(reduceMotion ? .none : .easeOut(duration: Theme.enterDuration), value: model.visibleItems.map(\.id))
            .onChange(of: model.selectedIndex) { _, newIndex in
                if reduceMotion {
                    proxy.scrollTo(newIndex, anchor: .center)
                } else {
                    withAnimation(Theme.selectionSpring) { proxy.scrollTo(newIndex, anchor: .center) }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.on.clipboard")
                .font(.largeTitle)
                .foregroundStyle(Theme.secondaryText)
            Text(emptyMessage)
                .font(Theme.bodyFont)
                .foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyMessage: String {
        if model.isSearching { return "No Matches" }
        if model.selectedCollectionID == CollectionSeed.historyID { return "Copy something to get started" }
        return "No items in \(model.selectedCollectionName) yet"
    }
}
