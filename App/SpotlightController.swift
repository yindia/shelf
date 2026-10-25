import AppKit
import Combine
import Core
import SwiftUI
import UI

/// A centered, floating, non-activating Spotlight-style search window.
@MainActor
final class SpotlightController {
    private let panel: SpotlightPanel
    private let model: SpotlightViewModel
    private var keyMonitor: Any?
    private var cancellable: AnyCancellable?
    /// Fixed screen Y for the window's top edge, so the field stays put while
    /// the results list grows downward.
    private var anchorTop: CGFloat = 0

    init(model: SpotlightViewModel) {
        self.model = model
        let rect = NSRect(x: 0, y: 0, width: Theme.spotlightWidth, height: 420)
        panel = SpotlightPanel(contentRect: rect,
                               styleMask: [.nonactivatingPanel, .borderless],
                               backing: .buffered, defer: true)
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.appearance = nil
        let hosting = NSHostingView(rootView: SpotlightSearchView(model: model))
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentView = hosting
    }

    var isVisible: Bool { panel.isVisible }
    func toggle() { isVisible ? hide() : show() }

    func show() {
        model.reset()
        if let f = NSScreen.main?.visibleFrame {
            anchorTop = f.minY + f.height * 0.72   // window's top edge
        }
        applyLayout()
        panel.makeKeyAndOrderFront(nil)
        installKeyMonitor()
        // Re-size/anchor the window as the results list changes.
        cancellable = model.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.applyLayout() }
    }

    func hide() {
        removeKeyMonitor()
        cancellable = nil
        panel.orderOut(nil)
    }

    /// Sizes the window to field + results and keeps its top edge anchored.
    private func applyLayout() {
        guard let screen = NSScreen.main else { return }
        let count = min(model.results.count, Theme.spotlightMaxRows)
        let listHeight = model.results.isEmpty ? 0 : 1 + CGFloat(count) * Theme.spotlightRowHeight
        let height = Theme.spotlightFieldHeight + listHeight
        let w = Theme.spotlightWidth
        let x = screen.visibleFrame.minX + (screen.visibleFrame.width - w) / 2
        panel.setFrame(NSRect(x: x, y: anchorTop - height, width: w, height: height), display: true)
    }

    private func installKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            return self.handle(event) ? nil : event
        }
    }
    private func removeKeyMonitor() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
    }

    private func handle(_ event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers?.lowercased() == "c" {
            model.copySelection(); hide(); return true
        }
        // Backspace on empty field removes the last filter token.
        if event.keyCode == 51, model.searchText.isEmpty, !model.activeSearchTokens.isEmpty {
            model.removeLastToken(); return true
        }
        switch event.keyCode {
        case 125: model.moveDown(); return true   // down
        case 126: model.moveUp(); return true     // up
        case 36, 76:                               // return
            if let suggestion = model.searchSuggestions.first { model.applyToken(suggestion) }
            else { model.activateSelection() }
            return true
        case 53: model.dismiss(); return true     // escape
        default: return false                     // typing flows to the field
        }
    }
}

/// Borderless panels don't become key by default; allow it for the search field.
private final class SpotlightPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
