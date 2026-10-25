import Combine
import Core
import Foundation

/// Drives the panel: owns collections, the selected collection filter, the item
/// list for that filter, selection, search, and the new-collection flow.
@MainActor
public final class PanelViewModel: ObservableObject {
    @Published public private(set) var items: [ClipItemModel] = []
    /// Every item across all collections — the search corpus.
    @Published public private(set) var allItems: [ClipItemModel] = []
    /// Structured Power Search filters (type / app / pinboard / date).
    @Published public var filters = SearchFilters()
    @Published public private(set) var collections: [Collection] = []
    @Published public var selectedCollectionID: UUID
    @Published public var selectedIndex: Int = 0
    @Published public var isSearching = false
    @Published public var searchText = ""
    @Published public var isCreatingCollection = false
    @Published public var isEditingRules = false
    @Published public var isEditingPrivacy = false
    @Published public var privacy: PrivacySettings
    private let onPrivacyChanged: @MainActor (PrivacySettings) -> Void
    @Published public var autoRules: AutoCategorizationRules
    private let onRulesChanged: @MainActor (AutoCategorizationRules) -> Void

    /// Pagination: start small, grow as the user scrolls.
    private let pageSize = 30
    private var pageLimit = 30
    private var isLoadingMore = false
    /// True until a collection's first page has loaded (shows a spinner).
    @Published public private(set) var isLoading = false

    private let itemRepo: ItemRepositoryReading
    private let itemWriter: ItemRepositoryWriting?
    private let collectionRepo: CollectionRepository
    private let onPaste: @MainActor (ClipItemModel, Bool) -> Void
    private let onCopy: @MainActor (ClipItemModel) -> Void
    private let onDismiss: @MainActor () -> Void
    private var itemsTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    /// Debounced, cached Power Search results so we don't re-rank on every render.
    @Published public private(set) var searchResults: [ClipItemModel] = []
    /// Cached distinct source apps (recomputed only when the corpus changes).
    @Published public private(set) var availableApps: [String] = []

    public init(
        itemRepository: ItemRepositoryReading,
        itemWriter: ItemRepositoryWriting? = nil,
        collectionRepository: CollectionRepository,
        onPaste: @escaping @MainActor (ClipItemModel, Bool) -> Void,
        onCopy: @escaping @MainActor (ClipItemModel) -> Void = { _ in },
        onDismiss: @escaping @MainActor () -> Void,
        autoRules: AutoCategorizationRules = AutoCategorizationRules.defaults,
        onRulesChanged: @escaping @MainActor (AutoCategorizationRules) -> Void = { _ in },
        privacy: PrivacySettings = PrivacySettings(),
        onPrivacyChanged: @escaping @MainActor (PrivacySettings) -> Void = { _ in }
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
        self.privacy = privacy
        self.onPrivacyChanged = onPrivacyChanged
        setUpSearchPipeline()
    }

    /// Recompute search results off the render path: debounce keystrokes/filter
    /// changes and rank once, caching the result.
    private func setUpSearchPipeline() {
        $allItems
            .map { Array(Set($0.compactMap(\.sourceBundleID))).sorted() }
            .removeDuplicates()
            .assign(to: &$availableApps)

        Publishers.CombineLatest4($searchText, $filters, $allItems, $isSearching)
            .debounce(for: .milliseconds(120), scheduler: DispatchQueue.main)
            .sink { [weak self] text, filters, items, searching in
                guard let self else { return }
                self.searchResults = searching ? PowerSearch.run(items, text: text, filters: filters) : []
            }
            .store(in: &cancellables)
    }

    public func beginEditRules() { isEditingRules = true }
    public func beginEditPrivacy() { isEditingPrivacy = true }
    public func commitPrivacy(_ settings: PrivacySettings) {
        privacy = settings
        onPrivacyChanged(settings)
    }

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

    /// Items after applying the search filter (cached; see setUpSearchPipeline).
    public var visibleItems: [ClipItemModel] {
        isSearching ? searchResults : items
    }

    public func togglePinboardFilter(_ id: UUID) { toggle(&filters.pinboards, id) }
    public func toggleKind(_ kind: ClipKind) { toggle(&filters.kinds, kind) }
    public func toggleApp(_ app: String) { toggle(&filters.apps, app) }
    public func setDate(_ date: DateFilter) { filters.date = date; selectedIndex = 0 }
    public func clearFilters() { filters = SearchFilters(); selectedIndex = 0 }

    // MARK: Power Search tokens (inline chips + autocomplete)

    private var availableAppPairs: [(id: String, name: String)] {
        availableApps.map { ($0, SourceAppIcon.name(for: $0) ?? $0) }
    }

    /// Autocomplete suggestions for the text currently being typed.
    public var searchSuggestions: [SearchToken] {
        SearchSuggestions.matches(partial: searchText, apps: availableAppPairs,
                                  collections: collections, active: filters)
    }

    /// Active filters as removable inline tokens.
    public var activeSearchTokens: [SearchToken] {
        SearchSuggestions.activeTokens(filters, collections: collections,
                                       appName: { SourceAppIcon.name(for: $0) ?? $0 })
    }

    /// Add a filter from a chosen suggestion, clearing the typed partial.
    public func applyToken(_ token: SearchToken) {
        switch token {
        case .kind(let k): filters.kinds.insert(k)
        case .app(let b, _): filters.apps.insert(b)
        case .date(let d): filters.date = d
        case .pinboard(let id, _): filters.pinboards.insert(id)
        }
        searchText = ""
        selectedIndex = 0
    }

    public func removeToken(_ token: SearchToken) {
        switch token {
        case .kind(let k): filters.kinds.remove(k)
        case .app(let b, _): filters.apps.remove(b)
        case .date: filters.date = .any
        case .pinboard(let id, _): filters.pinboards.remove(id)
        }
        selectedIndex = 0
    }

    /// Remove the last token (backspace on an empty field).
    public func removeLastToken() {
        if let last = activeSearchTokens.last { removeToken(last) }
    }

    private func toggle<T: Hashable>(_ set: inout Set<T>, _ value: T) {
        if set.contains(value) { set.remove(value) } else { set.insert(value) }
        selectedIndex = 0
    }

    @Published public var editingItem: ClipItemModel?
    @Published public var isCreatingText = false

    public func beginNewText() { isCreatingText = true }

    /// Pin/unpin a clip (pinned sorts to the top).
    public func setPinned(_ item: ClipItemModel, pinned: Bool) {
        guard let itemWriter else { return }
        Task { try? await itemWriter.setPinned(itemID: item.id, pinned: pinned); await refresh() }
    }

    /// Create a new plain-text clip in the current pinboard (or History).
    public func createTextItem(_ text: String) {
        guard let itemWriter, !text.isEmpty else { return }
        let list = selectedCollectionID
        Task { _ = try? await itemWriter.insert(.text(text, listID: list)); await refresh() }
    }

    /// Replace one representation's bytes (image rotate / color edit).
    public func replaceRepresentation(_ item: ClipItemModel, type: String, data: Data) {
        guard let itemWriter else { return }
        Task { try? await itemWriter.setRepresentation(itemID: item.id, typeIdentifier: type, data: data); await refresh() }
    }

    private func refresh() async {
        if let latest = try? await itemRepo.recentItems(limit: 200, listID: selectedCollectionID) {
            items = latest
        }
    }
    /// Set while jumping to an item; resolved to a selection once its collection loads.
    private var pendingJumpID: UUID?

    /// "Jump to History": leave search and reveal the item in its collection
    /// (Clipboard History or its pinboard), with everything around it in place.
    public func jump(to item: ClipItemModel) {
        if isSearching { isSearching = false; searchText = "" }
        pendingJumpID = item.id
        let target = item.listID ?? CollectionSeed.historyID
        if target == selectedCollectionID {
            applyPendingJump()           // already in this collection
        } else {
            selectCollection(target)     // resubscribe; jump applied when items arrive
        }
    }

    private func applyPendingJump() {
        guard let id = pendingJumpID, let index = items.firstIndex(where: { $0.id == id }) else { return }
        selectedIndex = index
        pendingJumpID = nil
    }

    /// Rename a clip and/or replace its plain text; persists to the store.
    public func applyEdit(_ item: ClipItemModel, title: String?, text: String?) {
        guard let itemWriter else { return }
        Task {
            try? await itemWriter.setTitle(itemID: item.id, title: title?.isEmpty == true ? nil : title)
            if let text, !text.isEmpty { try? await itemWriter.setText(itemID: item.id, text: text) }
            if let latest = try? await itemRepo.recentItems(limit: 200, listID: selectedCollectionID) {
                items = latest
            }
        }
    }

    public func activate() {
        Task { await loadCollections() }
        subscribe(to: selectedCollectionID)
        subscribeAll()
    }

    private var allTask: Task<Void, Never>?
    /// Always-on stream of every item, used as the cross-pinboard search corpus.
    private func subscribeAll() {
        guard allTask == nil else { return }
        allTask = Task { [weak self] in
            guard let self else { return }
            for await latest in self.itemRepo.changes(limit: 500, listID: nil) {
                self.allItems = latest
            }
        }
    }

    public func selectCollection(_ id: UUID) {
        guard id != selectedCollectionID else { return }
        selectedCollectionID = id
        selectedIndex = 0
        pageLimit = pageSize   // reset pagination for the new collection
        // Clear immediately so no stale cards linger behind the empty state;
        // the resubscribed stream repopulates with the new collection's items.
        items = []
        subscribe(to: id)
    }

    /// Grows the page when the user nears the end of the loaded cards.
    public func loadMoreIfNeeded(currentIndex: Int) {
        guard !isSearching, !isLoadingMore else { return }
        // Only page up when a full page is loaded (more likely exist).
        guard items.count >= pageLimit, currentIndex >= items.count - 5 else { return }
        isLoadingMore = true
        pageLimit += pageSize
        subscribe(to: selectedCollectionID)
    }

    /// Delete every clip (Clear All).
    public func clearAll() {
        guard let itemWriter else { return }
        items = []
        Task { try? await itemWriter.deleteAll() }
    }

    private func loadCollections() async {
        try? await collectionRepo.seedIfNeeded(CollectionSeed.starters)
        if let loaded = try? await collectionRepo.collections() {
            collections = loaded
        }
    }

    private func subscribe(to listID: UUID) {
        itemsTask?.cancel()
        if items.isEmpty { isLoading = true }
        itemsTask = Task { [weak self] in
            guard let self else { return }
            for await latest in self.itemRepo.changes(limit: self.pageLimit, listID: listID) {
                self.items = latest
                self.isLoading = false
                self.isLoadingMore = false
                self.selectedIndex = min(self.selectedIndex, max(0, latest.count - 1))
                self.applyPendingJump()
            }
        }
    }

    deinit { itemsTask?.cancel(); allTask?.cancel() }

    // MARK: Intents

    public func moveLeft() { selectIndex(selectedIndex - 1) }
    public func moveRight() { selectIndex(selectedIndex + 1) }

    public func selectIndex(_ index: Int) {
        let count = visibleItems.count
        guard count > 0 else { return }
        selectedIndex = min(max(index, 0), count - 1)
    }

    public func activateNumber(_ number: Int, plainText: Bool = false) {
        activate(index: number - 1, plainText: plainText)
    }

    public func activateSelection(plainText: Bool = false) {
        activate(index: selectedIndex, plainText: plainText)
    }

    /// Paste a specific item (context menu / shared with Return + double-click).
    public func activate(item: ClipItemModel, plainText: Bool = false) {
        onPaste(item, plainText)
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
    public func activate(index: Int, plainText: Bool = false) {
        let visible = visibleItems
        guard visible.indices.contains(index) else { return }
        selectedIndex = index
        onPaste(visible[index], plainText)
    }

    /// The item currently under the keyboard selection (for Quick Look).
    public var selectedItem: ClipItemModel? {
        let visible = visibleItems
        return visible.indices.contains(selectedIndex) ? visible[selectedIndex] : nil
    }

    public func toggleSearch() {
        isSearching.toggle()
        if !isSearching { searchText = ""; filters = SearchFilters() }
        selectedIndex = 0
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
