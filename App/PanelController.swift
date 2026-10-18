import AppKit
import Core
import SwiftUI
import UI

/// Non-activating, borderless floating `NSPanel` that hosts the SwiftUI carousel,
/// plus a local key monitor for the keyboard-first interaction model.
@MainActor
final class PanelController {
    private let panel: KeyPanel
    private let model: PanelViewModel
    private var keyMonitor: Any?

    init(model: PanelViewModel, previewLoader: MediaPreviewLoader) {
        self.model = model

        let screenWidth = NSScreen.main?.frame.width ?? 1440
        let rect = NSRect(x: 0, y: 0, width: screenWidth, height: Theme.panelHeight)
        panel = KeyPanel(
            contentRect: rect,
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: true
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        // Track system light/dark so the glass material adapts.
        panel.appearance = nil
        let hosting = NSHostingView(rootView: PanelView(model: model, previewLoader: previewLoader))
        // Keep the hosting view transparent so the visual-effect view shows through.
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentView = hosting
    }

    var isVisible: Bool { panel.isVisible }

    func toggle() { isVisible ? hide() : show() }

    func show() {
        positionAtBottom()
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Theme.panelFadeDuration
            panel.animator().alphaValue = 1
        }
        installKeyMonitor()
    }

    func hide() {
        removeKeyMonitor()
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = Theme.panelFadeDuration
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            MainActor.assumeIsolated { self?.panel.orderOut(nil) }
        })
    }

    private func positionAtBottom() {
        guard let screen = NSScreen.main else { return }
        // Flush with the bottom of the usable area (above the Dock), full width.
        let frame = screen.visibleFrame
        panel.setFrame(
            NSRect(x: frame.minX, y: frame.minY, width: frame.width, height: Theme.panelHeight),
            display: true
        )
    }

    // MARK: Keyboard

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

    /// Returns true if the event was consumed.
    private func handle(_ event: NSEvent) -> Bool {
        // ⌘1…⌘9 → paste that card.
        if event.modifierFlags.contains(.command),
           let chars = event.charactersIgnoringModifiers,
           let number = Int(chars), (1...9).contains(number) {
            model.activateNumber(number)
            return true
        }

        switch event.keyCode {
        case 123: model.moveLeft(); return true      // left arrow
        case 124: model.moveRight(); return true     // right arrow
        case 36, 76: model.activateSelection(); return true  // return / keypad enter
        case 53:                                       // escape — one-way hide
            if model.isSearching {
                // First Esc exits search back to the carousel; second Esc hides.
                model.toggleSearch()
            } else {
                model.dismiss()
            }
            return true
        default: return false
        }
    }
}

/// Borderless panels don't become key by default; allow it so we can read keys.
private final class KeyPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
