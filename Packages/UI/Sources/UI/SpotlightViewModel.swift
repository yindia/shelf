import Combine
import Core
import Foundation
import SwiftUI

/// Drives the global Spotlight-style search window. Subscribes to all clipboard
/// items and filters them with the shared search backend; paste/copy route
/// through the same callbacks the main panel uses.
@MainActor
public final class SpotlightViewModel: ObservableObject {
    @Published public private(set) var allItems: [ClipItemModel] = []
    @Published public private(set) var collections: [Collection] = []
    @Published public var searchText = ""
    @Published public var selectedIndex = 0
    @Published public var filters = SearchFilters()
    @Published public private(set) var searchResults: [ClipItemModel] = []
    private var cancellables = Set<AnyCancellable>()
    private let semanticRanker = SemanticRanker()

    private let itemRepo: ItemRepositoryReading
    private let collectionRepo: CollectionRepository
    private let onActivate: @MainActor (ClipItemModel) -> Void
    private let onCopy: @MainActor (ClipItemModel) -> Void
    private let onDismiss: @MainActor () -> Void
    private var task: Task<Void, Never>?

    public init(
        itemRepository: ItemRepositoryReading,
        collectionRepository: CollectionRepository,
        onActivate: @escaping @MainActor (ClipItemModel) -> Void,
        onCopy: @escaping @MainActor (ClipItemModel) -> Void,
        onDismiss: @escaping @MainActor () -> Void
    ) {
        self.itemRepo = itemRepository
        self.collectionRepo = collectionRepository
        self.onActivate = onActivate
        self.onCopy = onCopy
        self.onDismiss = onDismiss

        // Debounced, cached ranking so typing doesn't re-run Power Search per render.
        Publishers.CombineLatest3($searchText, $filters, $allItems)
            .debounce(for: .milliseconds(120), scheduler: DispatchQueue.main)
            .sink { [weak self] text, filters, items in
                guard let self else { return }
                if text.trimmingCharacters(in: .whitespaces).isEmpty && filters.isEmpty {
                    self.searchResults = Array(items.prefix(50))
                } else {
                    var results = PowerSearch.run(items, text: text, filters: filters)
                    if results.isEmpty, !text.trimmingCharacters(in: .whitespaces).isEmpty {
                        results = self.semanticRanker.rank(items, query: text)
                    }
                    self.searchResults = results
                }
            }
            .store(in: &cancellables)
    }

    public func activate() {
        guard task == nil else { return }
        task = Task { [weak self] in
            guard let self else { return }
            for await latest in self.itemRepo.changes(limit: 300, listID: nil) {
                self.allItems = latest
            }
        }
        Task { if let loaded = try? await collectionRepo.collections() { collections = loaded } }
    }

    deinit { task?.cancel() }

    /// Empty query → recent items; otherwise ranked Power Search over everything.
    public var results: [ClipItemModel] {
        searchResults
    }

    // MARK: Power Search tokens (same model as the main panel)

    private var availableAppPairs: [(id: String, name: String)] {
        Array(Set(allItems.compactMap(\.sourceBundleID))).sorted()
            .map { ($0, SourceAppIcon.name(for: $0) ?? $0) }
    }

    public var searchSuggestions: [SearchToken] {
        SearchSuggestions.matches(partial: searchText, apps: availableAppPairs,
                                  collections: collections, active: filters)
    }

    public var activeSearchTokens: [SearchToken] {
        SearchSuggestions.activeTokens(filters, collections: collections,
                                       appName: { SourceAppIcon.name(for: $0) ?? $0 })
    }

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

    public func removeLastToken() {
        if let last = activeSearchTokens.last { removeToken(last) }
    }

    public func color(for listID: UUID?) -> Color? {
        let id = listID ?? CollectionSeed.historyID
        return collections.first { $0.id == id }.flatMap { Color(hex: $0.colorHex) }
    }

    // MARK: Intents
    public func onSearchChanged() { selectedIndex = 0 }
    public func moveUp() { select(selectedIndex - 1) }
    public func moveDown() { select(selectedIndex + 1) }
    private func select(_ i: Int) {
        let n = results.count
        guard n > 0 else { return }
        selectedIndex = min(max(i, 0), n - 1)
    }

    public func activateSelection() {
        let r = results
        guard r.indices.contains(selectedIndex) else { return }
        onActivate(r[selectedIndex])
    }
    public func copySelection() {
        let r = results
        guard r.indices.contains(selectedIndex) else { return }
        onCopy(r[selectedIndex])
    }
    public func dismiss() { onDismiss() }

    public func reset() { searchText = ""; selectedIndex = 0 }
}
