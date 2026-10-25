import Foundation

/// Ordered stack of copied items for sequential pasting (Paste Stack).
///
/// Activate with ⇧⌘C: every subsequent copy is pushed onto the stack. Each ⌘V
/// then pops the next item (top-to-bottom, or reversed) and pastes it.
@MainActor
public final class PasteStackModel: ObservableObject {
    @Published public private(set) var items: [ClipItemModel] = []
    @Published public private(set) var isActive = false
    /// Paste direction: false = top-to-bottom (oldest first), true = reversed.
    @Published public var reversed = false

    public init() {}

    public func activate() {
        items = []
        reversed = false
        isActive = true
    }

    public func deactivate() {
        isActive = false
        items = []
    }

    /// Append a freshly captured item while the stack is active.
    public func push(_ item: ClipItemModel) {
        guard isActive else { return }
        items.append(item)
    }

    public func remove(_ id: UUID) {
        items.removeAll { $0.id == id }
    }

    public func toggleDirection() { reversed.toggle() }

    /// Pop the next item to paste, respecting direction. Nil when empty.
    public func popNext() -> ClipItemModel? {
        guard isActive, !items.isEmpty else { return nil }
        return reversed ? items.removeLast() : items.removeFirst()
    }

    public var isEmpty: Bool { items.isEmpty }
}
