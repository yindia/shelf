import AppKit
import Core
import Platform
import SwiftUI
import UI

/// Owns the Paste Stack window + the global ⌘V tap. The window is a
/// non-activating floating panel so the target app stays frontmost and receives
/// the real ⌘V; the tap stages the next stack item onto the pasteboard first.
@MainActor
final class PasteStackController {
    let stack = PasteStackModel()
    private let panel: NSPanel
    private let pasteboard: SystemPasteboard
    /// Suppress re-capture of an item we just wrote to the pasteboard.
    private let suppress: (String) -> Void
    private var tap: PasteStackTap?

    init(pasteboard: SystemPasteboard, suppress: @escaping (String) -> Void) {
        self.pasteboard = pasteboard
        self.suppress = suppress

        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 300),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: true
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let hosting = NSHostingView(rootView: PasteStackView(stack: stack, onClose: { [weak panel] in
            panel?.orderOut(nil)
        }))
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentView = hosting
    }

    var isActive: Bool { stack.isActive }

    func toggle() { stack.isActive ? deactivate() : activate() }

    func activate() {
        stack.activate()
        sizeAndPosition()
        panel.orderFrontRegardless()
        let tap = PasteStackTap { [weak self] in self?.stagePaste() ?? false }
        tap.start()
        self.tap = tap
    }

    func deactivate() {
        tap?.stop()
        tap = nil
        panel.orderOut(nil)
        stack.deactivate()
    }

    /// Called on the main thread by the ⌘V tap: write the next item to the
    /// pasteboard so the in-flight paste pastes it. Returns false when empty.
    private func stagePaste() -> Bool {
        guard let item = stack.popNext() else {
            if stack.isEmpty { deactivate() }
            return false
        }
        suppress(Fingerprint.make(item.representations))
        pasteboard.write(item.representations, markSynthetic: true)
        if stack.isEmpty { panel.orderOut(nil) }
        return true
    }

    private func sizeAndPosition() {
        guard let screen = NSScreen.main else { return }
        panel.layoutIfNeeded()
        let size = panel.contentView?.fittingSize ?? NSSize(width: 360, height: 300)
        let frame = screen.visibleFrame
        let origin = NSPoint(x: frame.midX - size.width / 2, y: frame.midY - size.height / 2)
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
    }
}
