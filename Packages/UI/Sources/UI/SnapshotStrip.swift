import Core
import SwiftUI

/// Static tab bar + card carousel for snapshots/previews (no view model).
public struct SnapshotStrip: View {
    private let collections: [Collection]
    private let selectedCollectionID: UUID
    private let items: [ClipItemModel]
    private let selectedIndex: Int
    @ObservedObject private var previewLoader: MediaPreviewLoader

    public init(
        collections: [Collection],
        selectedCollectionID: UUID,
        items: [ClipItemModel],
        selectedIndex: Int,
        previewLoader: MediaPreviewLoader
    ) {
        self.collections = collections
        self.selectedCollectionID = selectedCollectionID
        self.items = items
        self.selectedIndex = selectedIndex
        self.previewLoader = previewLoader
    }

    private func headerColor(for item: ClipItemModel) -> Color {
        let collection = collections.first { $0.id == item.listID }
            ?? collections.first(where: \.isDefault)
        return Theme.headerColor(collection: collection, kind: item.kind)
    }

    public var body: some View {
        ZStack {
            GlassSurface()

            VStack(spacing: 0) {
                CollectionTabBar(
                    collections: collections,
                    selectedID: selectedCollectionID,
                    isSearching: false,
                    searchText: .constant(""),
                    onSelect: { _ in }, onToggleSearch: {}, onAdd: {}, onMove: { _, _ in }
                )
                Divider().opacity(0.5)
                HStack(spacing: Theme.cardSpacing) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        ItemCardView(
                            item: item,
                            index: index,
                            isSelected: index == selectedIndex,
                            headerColor: headerColor(for: item),
                            headerBand: Theme.headerBandColor(
                                collection: collections.first { $0.id == item.listID } ?? collections.first(where: \.isDefault),
                                kind: item.kind, increaseContrast: false)
                        )
                    }
                }
                .padding(.horizontal, Theme.panelPadding)
                .padding(.top, Theme.cardsTopInset)
                .padding(.bottom, Theme.carouselVInset)
            }
        }
        .frame(height: Theme.panelHeight)
        .environmentObject(previewLoader)
    }
}
