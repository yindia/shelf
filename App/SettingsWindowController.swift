import AppKit
import SwiftUI
import UI

/// Hosts the unified Apple-style Settings window (sidebar + panes). A standard
/// titled window, reused across opens — not the floating clipboard panel.
@MainActor
final class SettingsWindowController {
    private let window: NSWindow

    init(model: PanelViewModel) {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 480),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )
        window.title = "Shelf Settings"
        window.titlebarAppearsTransparent = false
        window.isReleasedWhenClosed = false
        window.center()
        window.contentView = NSHostingView(rootView: SettingsView(model: model))
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        if !window.isVisible { window.center() }
        window.makeKeyAndOrderFront(nil)
    }
}
