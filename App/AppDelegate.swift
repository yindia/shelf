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
    private var isPaused = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            let environment = try AppEnvironment()
            self.environment = environment

            let savedRules = AutoRulesPersistence.load()
            let savedPrivacy = PrivacyPersistence.load()
            let model = PanelViewModel(
                itemRepository: environment.repository,
                itemWriter: environment.repository,
                collectionRepository: environment.repository,
                onPaste: { [weak self] item, plain in self?.paste(item, plainText: plain) },
                onCopy: { [weak self] item in self?.copyOnly(item) },
                onDismiss: { [weak self] in self?.panelController?.hide() },
                autoRules: savedRules,
                onRulesChanged: { [weak environment] rules in
                    AutoRulesPersistence.save(rules)
                    Task { await environment?.capture.setRules(rules) }
                },
                privacy: savedPrivacy,
                onPrivacyChanged: { [weak self, weak environment] privacy in
                    PrivacyPersistence.save(privacy)
                    self?.panelController?.setVisibleDuringScreenSharing(privacy.showDuringScreenSharing)
                    Task { await environment?.capture.setIgnoreConfidential(privacy.ignoreConfidential) }
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
            self.panelController?.onQuickLook = { [weak self] in self?.quickLookSelected() }

            setUpStatusItem()
            setUpHotKey()

            // Apply saved privacy settings.
            self.panelController?.setVisibleDuringScreenSharing(savedPrivacy.showDuringScreenSharing)
            Task { await environment.capture.setIgnoreConfidential(savedPrivacy.ignoreConfidential) }

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
        menu.addItem(withTitle: "New Text Item", action: #selector(newTextItem), keyEquivalent: "n")
        pauseMenuItem = menu.addItem(withTitle: "Pause Capture", action: #selector(togglePause), keyEquivalent: "p")
        menu.addItem(.separator())

        // Settings submenu.
        let settings = NSMenuItem(title: "Settings", action: nil, keyEquivalent: "")
        let settingsMenu = NSMenu()
        settingsMenu.addItem(withTitle: "Privacy…", action: #selector(openPrivacy), keyEquivalent: "")
        settingsMenu.addItem(withTitle: "Auto-Categorization…", action: #selector(openRules), keyEquivalent: "")
        settingsMenu.items.forEach { $0.target = self }
        settings.submenu = settingsMenu
        menu.addItem(settings)

        menu.addItem(withTitle: "About Shelf", action: #selector(showAbout), keyEquivalent: "")
        menu.addItem(withTitle: "Shelf Help", action: #selector(openHelp), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Shelf", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.items.forEach { if $0.target == nil { $0.target = self } }
        item.menu = menu
        statusItem = item
    }

    // MARK: Menu actions

    /// Shows the panel (so the sheet has a window to attach to) then runs `action`.
    private func presentingPanel(_ action: @escaping () -> Void) {
        if panelController?.isVisible != true {
            previousApp = NSWorkspace.shared.frontmostApplication
            panelController?.show()
        }
        action()
    }

    @objc private func openPrivacy() { presentingPanel { [weak self] in self?.model?.beginEditPrivacy() } }
    @objc private func openRules() { presentingPanel { [weak self] in self?.model?.beginEditRules() } }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "Shelf",
            .applicationVersion: version,
            .credits: NSAttributedString(
                string: """
                Your clipboard, with superpowers.

                Shelf keeps everything you copy — text, links, images, files, \
                colors, and code — on a fast, keyboard-first glass shelf. \
                Organize clips into pinboards, find anything instantly with \
                Power Search (including text inside screenshots), preview with \
                Quick Look, and paste it back anywhere.

                github.com/yindia/shelf
                """,
                attributes: [.font: NSFont.systemFont(ofSize: 11),
                             .foregroundColor: NSColor.secondaryLabelColor]
            ),
        ])
    }

    @objc private func openHelp() {
        if let url = URL(string: "https://github.com/yindia/shelf") { NSWorkspace.shared.open(url) }
    }

    private var pauseMenuItem: NSMenuItem?

    @objc private func newTextItem() {
        if panelController?.isVisible != true {
            previousApp = NSWorkspace.shared.frontmostApplication
            panelController?.show()
        }
        model?.beginNewText()
    }

    @objc private func togglePause() {
        isPaused.toggle()
        Task { await environment?.capture.setPaused(isPaused) }
        pauseMenuItem?.title = isPaused ? "Resume Capture" : "Pause Capture"
        statusItem?.button?.image = NSImage(
            systemSymbolName: isPaused ? "pause.circle" : "doc.on.clipboard",
            accessibilityDescription: isPaused ? "Shelf (paused)" : "Shelf"
        )
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

    /// Open Quick Look for the selected item (Space).
    func quickLookSelected() {
        guard let item = model?.selectedItem, QuickLookPresenter.canPreview(item) else { return }
        environment?.quickLook.toggle(for: item)
    }

    private func paste(_ item: ClipItemModel, plainText: Bool) {
        panelController?.hide()
        guard let environment else { return }
        // The item is written to the pasteboard either way; suppress re-capture of
        // our own write regardless of whether the synthetic paste succeeds.
        Task { await environment.capture.suppress(fingerprint: Fingerprint.make(item.representations)) }
        do {
            _ = try environment.pasteBack.paste(item.representations, to: previousApp, plainTextOnly: plainText)
        } catch {
            // Accessibility not granted: the content is copied (copy-only fallback);
            // prompt so the next paste can be synthetic.
            _ = AccessibilityPermission.check(prompt: true)
        }
    }
}
