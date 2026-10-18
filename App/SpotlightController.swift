import AppKit
import Core
import SwiftUI
import UI

/// A centered, floating, non-activating Spotlight-style search window.
@MainActor
final class SpotlightController {
    private let panel: SpotlightPanel
    private let model: SpotlightViewModel
    private var keyMonitor: Any?

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
        center()
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(panel.contentView)
        installKeyMonitor()
    }

    func hide() {
        removeKeyMonitor()
        panel.orderOut(nil)
    }

    private func center() {
        guard let screen = NSScreen.main else { return }
        let f = screen.visibleFrame
        // Size to fit content; place a bit above center (Spotlight-like).
        panel.layoutIfNeeded()
        let size = panel.contentView?.fittingSize ?? NSSize(width: Theme.spotlightWidth, height: 120)
        let w = Theme.spotlightWidth
        let x = f.minX + (f.width - w) / 2
        let y = f.minY + f.height * 0.62 - size.height / 2
        panel.setFrame(NSRect(x: x, y: y, width: w, height: max(size.height, Theme.spotlightFieldHeight)), display: true)
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
        switch event.keyCode {
        case 125: model.moveDown(); return true   // down
        case 126: model.moveUp(); return true     // up
        case 36, 76: model.activateSelection(); return true  // return
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
