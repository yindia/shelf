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
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            return Array(allItems.prefix(50))
        }
        return PowerSearch.run(allItems, text: searchText, filters: SearchFilters())
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
