import Combine
import Core
import Foundation

/// Drives the panel: owns collections, the selected collection filter, the item
/// list for that filter, selection, search, and the new-collection flow.
@MainActor
public final class PanelViewModel: ObservableObject {
    @Published public private(set) var items: [ClipItemModel] = []
    @Published public private(set) var collections: [Collection] = []
    @Published public var selectedCollectionID: UUID
    @Published public var selectedIndex: Int = 0
    @Published public var isSearching = false
    @Published public var searchText = ""
    @Published public var isCreatingCollection = false
    @Published public var isEditingRules = false
    @Published public var autoRules: AutoCategorizationRules
    private let onRulesChanged: @MainActor (AutoCategorizationRules) -> Void

    private let itemRepo: ItemRepositoryReading
    private let itemWriter: ItemRepositoryWriting?
    private let collectionRepo: CollectionRepository
    private let onPaste: @MainActor (ClipItemModel) -> Void
    private let onCopy: @MainActor (ClipItemModel) -> Void
    private let onDismiss: @MainActor () -> Void
    private var itemsTask: Task<Void, Never>?

    public init(
        itemRepository: ItemRepositoryReading,
        itemWriter: ItemRepositoryWriting? = nil,
        collectionRepository: CollectionRepository,
        onPaste: @escaping @MainActor (ClipItemModel) -> Void,
        onCopy: @escaping @MainActor (ClipItemModel) -> Void = { _ in },
        onDismiss: @escaping @MainActor () -> Void,
        autoRules: AutoCategorizationRules = AutoCategorizationRules.defaults,
        onRulesChanged: @escaping @MainActor (AutoCategorizationRules) -> Void = { _ in }
    ) {
        self.itemRepo = itemRepository
        self.itemWriter = itemWriter
        self.collectionRepo = collectionRepository
        self.selectedCollectionID = CollectionSeed.historyID
        self.onPaste = onPaste
        self.onCopy = onCopy
        self.onDismiss = onDismiss
        self.autoRules = autoRules
        self.onRulesChanged = onRulesChanged
    }

    public func beginEditRules() { isEditingRules = true }

    /// Persist + apply rule changes (pushes to the capture pipeline).
    public func commitRules(_ rules: AutoCategorizationRules) {
        autoRules = rules
        onRulesChanged(rules)
    }

    /// Name of the active collection (for the empty-state label).
    public var selectedCollectionName: String {
        collections.first { $0.id == selectedCollectionID }?.name ?? "Collection"
    }

    /// Lookup for card header colors by collection id.
    public func color(for listID: UUID?) -> Collection? {
        guard let listID else { return collections.first(where: \.isDefault) }
        return collections.first { $0.id == listID } ?? collections.first(where: \.isDefault)
    }

    /// Items after applying the search filter.
    public var visibleItems: [ClipItemModel] {
        guard isSearching, !searchText.isEmpty else { return items }
        let needle = searchText.lowercased()
        return items.filter { ($0.plainText ?? "").lowercased().contains(needle) }
    }

    public func activate() {
        Task { await loadCollections() }
        subscribe(to: selectedCollectionID)
    }

    public func selectCollection(_ id: UUID) {
        guard id != selectedCollectionID else { return }
        selectedCollectionID = id
        selectedIndex = 0
        // Clear immediately so no stale cards linger behind the empty state;
        // the resubscribed stream repopulates with the new collection's items.
        items = []
        subscribe(to: id)
    }

    private func loadCollections() async {
        try? await collectionRepo.seedIfNeeded(CollectionSeed.starters)
        if let loaded = try? await collectionRepo.collections() {
            collections = loaded
        }
    }

    private func subscribe(to listID: UUID) {
        itemsTask?.cancel()
        itemsTask = Task { [weak self] in
            guard let self else { return }
            for await latest in self.itemRepo.changes(limit: 200, listID: listID) {
                self.items = latest
                self.selectedIndex = min(self.selectedIndex, max(0, latest.count - 1))
            }
        }
    }

    deinit { itemsTask?.cancel() }

    // MARK: Intents

    public func moveLeft() { selectIndex(selectedIndex - 1) }
    public func moveRight() { selectIndex(selectedIndex + 1) }

    public func selectIndex(_ index: Int) {
        let count = visibleItems.count
        guard count > 0 else { return }
        selectedIndex = min(max(index, 0), count - 1)
    }

    public func activateNumber(_ number: Int) {
        activate(index: number - 1)
    }

    public func activateSelection() {
        activate(index: selectedIndex)
    }

    /// Paste a specific item (context menu / shared with Return + double-click).
    public func activate(item: ClipItemModel) {
        onPaste(item)
    }

    /// Copy an item back to the pasteboard without pasting or dismissing.
    public func copy(_ item: ClipItemModel) {
        onCopy(item)
    }

    /// Delete an item (and its blobs) entirely, then refresh the current view.
    public func delete(_ item: ClipItemModel) {
        guard let itemWriter else { return }
        items.removeAll { $0.id == item.id }
        Task { try? await itemWriter.delete(id: item.id) }
    }

    /// Single entry point for Return, double-click, and ⌘-number: selects then pastes.
    public func activate(index: Int) {
        let visible = visibleItems
        guard visible.indices.contains(index) else { return }
        selectedIndex = index
        onPaste(visible[index])
    }

    public func toggleSearch() {
        isSearching.toggle()
        if !isSearching { searchText = "" }
    }

    public func beginCreateCollection() { isCreatingCollection = true }

    /// Deletes a user collection; its clips move back to Clipboard History.
    /// The built-in History collection cannot be deleted.
    public func deleteCollection(_ id: UUID) {
        guard id != CollectionSeed.historyID else { return }
        Task {
            try? await collectionRepo.delete(collectionID: id, reassignTo: CollectionSeed.historyID)
            if selectedCollectionID == id { selectCollection(CollectionSeed.historyID) }
            await loadCollections()
        }
    }

    public func createCollection(name: String, colorHex: String, icon: String) {
        let new = Collection(
            id: UUID(),
            name: name,
            colorHex: colorHex,
            iconSymbol: icon,
            order: (collections.map(\.order).max() ?? 0) + 1
        )
        Task {
            _ = try? await collectionRepo.create(new)
            await loadCollections()
            isCreatingCollection = false
        }
    }

    /// Shared refile path: drag-and-drop onto a tab calls this.
    public func move(itemID: UUID, to listID: UUID) {
        guard let itemWriter else { return }
        Task {
            try? await itemWriter.setList(itemID: itemID, listID: listID)
            // Refresh current filter so a card that left the view animates out.
            if let latest = try? await itemRepo.recentItems(limit: 200, listID: selectedCollectionID) {
                items = latest
            }
        }
    }

    public func dismiss() { onDismiss() }
}
