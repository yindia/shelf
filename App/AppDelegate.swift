import AppKit
import Core
import Platform
import SwiftUI
import UI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var environment: AppEnvironment?
    private var statusItem: NSStatusItem?
    private var panelController: PanelController?
    private var hotKey: HotKey?
    private var model: PanelViewModel?
    /// App that was frontmost when the panel opened — the paste-back target.
    private var previousApp: NSRunningApplication?

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            let environment = try AppEnvironment()
            self.environment = environment

            let savedRules = AutoRulesPersistence.load()
            let model = PanelViewModel(
                itemRepository: environment.repository,
                itemWriter: environment.repository,
                collectionRepository: environment.repository,
                onPaste: { [weak self] item in self?.paste(item) },
                onCopy: { [weak self] item in self?.copyOnly(item) },
                onDismiss: { [weak self] in self?.panelController?.hide() },
                autoRules: savedRules,
                onRulesChanged: { [weak environment] rules in
                    AutoRulesPersistence.save(rules)
                    Task { await environment?.capture.setRules(rules) }
                }
            )
            model.activate()
            self.model = model
            Task { await environment.capture.setRules(savedRules) }
            let previewLoader = MediaPreviewLoader(
                thumbnailProvider: environment.thumbnailProvider,
                infoProvider: environment.mediaInfoProvider
            )
            self.panelController = PanelController(model: model, previewLoader: previewLoader)

            setUpStatusItem()
            setUpHotKey()

            Task { await environment.capture.start() }

            // Nudge for Accessibility on first launch (needed for paste-back).
            _ = AccessibilityPermission.check(prompt: true)
        } catch {
            NSLog("Shelf failed to start: \(error)")
            NSApp.terminate(nil)
        }
    }

    // MARK: Status item

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Shelf")

        let menu = NSMenu()
        menu.addItem(withTitle: "Show Shelf  (⇧⌘V)", action: #selector(togglePanel), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Shelf", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.items.forEach { $0.target = self }
        item.menu = menu
        statusItem = item
    }

    // MARK: Hotkey — ⇧⌘V

    private func setUpHotKey() {
        let hotKey = HotKey { [weak self] in self?.togglePanel() }
        hotKey.register(.init(keyCode: HotKeyCodes.v, modifiers: HotKeyCodes.cmd | HotKeyCodes.shift))
        self.hotKey = hotKey
    }

    @objc private func togglePanel() {
        guard let panelController else { return }
        if panelController.isVisible {
            panelController.hide()
        } else {
            previousApp = NSWorkspace.shared.frontmostApplication
            panelController.show()
        }
    }

    // MARK: Paste-back

    /// Copy-only: put the item back on the pasteboard without pasting/dismissing.
    private func copyOnly(_ item: ClipItemModel) {
        guard let environment else { return }
        Task { await environment.capture.suppress(fingerprint: Fingerprint.make(item.representations)) }
        environment.pasteboard.write(item.representations, markSynthetic: true)
    }

    private func paste(_ item: ClipItemModel) {
        panelController?.hide()
        guard let environment else { return }
        // The item is written to the pasteboard either way; suppress re-capture of
        // our own write regardless of whether the synthetic paste succeeds.
        Task { await environment.capture.suppress(fingerprint: Fingerprint.make(item.representations)) }
        do {
            _ = try environment.pasteBack.paste(item.representations, to: previousApp)
        } catch {
            // Accessibility not granted: the content is copied (copy-only fallback);
            // prompt so the next paste can be synthetic.
            _ = AccessibilityPermission.check(prompt: true)
        }
    }
}
