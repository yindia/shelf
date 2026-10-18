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
    private var spotlightHotKey: HotKey?
    private var spotlight: SpotlightController?
    private var model: PanelViewModel?
    /// App that was frontmost when the panel opened — the paste-back target.
    private var previousApp: NSRunningApplication?
    private var isPaused = false
    private var retention: RetentionWindow = .month
    private var pruneTimer: Timer?
    private var didPromptAccessibility = false

    /// Clears history older than the retention window (keeps pinned + pinboards).
    private func pruneHistory(_ window: RetentionWindow) {
        retention = window
        guard let cutoff = window.cutoff(), let environment else { return }
        Task { try? await environment.repository.prune(olderThan: cutoff) }
    }

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
                    Task {
                        await environment?.capture.setIgnoreConfidential(privacy.ignoreConfidential)
                        await environment?.capture.setIgnoredBundleIDs(privacy.excludedApps)
                    }
                    self?.pruneHistory(privacy.retention)
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

            // Global Spotlight-style search window (Option+Cmd+Space).
            let spotlightModel = SpotlightViewModel(
                itemRepository: environment.repository,
                collectionRepository: environment.repository,
                onActivate: { [weak self] item in self?.spotlight?.hide(); self?.paste(item, plainText: false) },
                onCopy: { [weak self] item in self?.copyOnly(item) },
                onDismiss: { [weak self] in self?.spotlight?.hide() }
            )
            spotlightModel.activate()
            self.spotlight = SpotlightController(model: spotlightModel)

            setUpStatusItem()
            setUpHotKey()

            // Apply saved privacy settings.
            self.panelController?.setVisibleDuringScreenSharing(savedPrivacy.showDuringScreenSharing)
            Task {
                await environment.capture.setIgnoreConfidential(savedPrivacy.ignoreConfidential)
                await environment.capture.setIgnoredBundleIDs(savedPrivacy.excludedApps)
            }

            Task { await environment.capture.start() }
            checkForUpdatesOnLaunch()

            // Enforce the retention window now and hourly.
            self.retention = savedPrivacy.retention
            self.pruneHistory(savedPrivacy.retention)
            self.pruneTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    self.pruneHistory(self.retention)
                }
            }

            // Nudge for Accessibility once on first launch (needed for paste-back).
            if !AccessibilityPermission.isTrusted {
                didPromptAccessibility = true
                _ = AccessibilityPermission.check(prompt: true)
            }
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
        pauseMenuItem = menu.addItem(withTitle: "Pause Capture", action: #selector(togglePause), keyEquivalent: "t")
        menu.addItem(withTitle: "Clear All History…", action: #selector(clearAll), keyEquivalent: "")
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
        updateMenuItem = menu.addItem(withTitle: "Check for Updates…", action: #selector(checkForUpdates), keyEquivalent: "")
        menu.addItem(withTitle: "Shelf Help", action: #selector(openHelp), keyEquivalent: "")
        menu.addItem(.separator())
        let quit = menu.addItem(withTitle: "Quit Shelf", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.items.forEach { if $0.target == nil { $0.target = self } }
        quit.target = NSApp   // terminate(_:) lives on NSApplication, not the delegate
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

    private var updateMenuItem: NSMenuItem?

    /// Silent check on launch: surface an update in the menu if one exists.
    private func checkForUpdatesOnLaunch() {
        Task {
            if let update = await UpdateChecker.check() {
                updateMenuItem?.title = "Update to v\(update.version)…"
            }
        }
    }

    @objc private func checkForUpdates() {
        Task {
            NSApp.activate(ignoringOtherApps: true)
            let alert = NSAlert()
            if let update = await UpdateChecker.check() {
                alert.messageText = "Update available"
                alert.informativeText = "Shelf v\(update.version) is available. Open the download page?"
                alert.addButton(withTitle: "Download")
                alert.addButton(withTitle: "Later")
                if alert.runModal() == .alertFirstButtonReturn {
                    NSWorkspace.shared.open(UpdateChecker.latestReleasePage)
                }
            } else {
                alert.messageText = "You’re up to date"
                alert.informativeText = "Shelf is running the latest version."
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
        }
    }

    private var pauseMenuItem: NSMenuItem?

    @objc private func newTextItem() {
        if panelController?.isVisible != true {
            previousApp = NSWorkspace.shared.frontmostApplication
            panelController?.show()
        }
        model?.beginNewText()
    }

    @objc private func clearAll() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Clear all clipboard history?"
        alert.informativeText = "This permanently deletes every saved clip. This cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Clear All")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn { model?.clearAll() }
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

        let spotlightHotKey = HotKey { [weak self] in self?.toggleSpotlight() }
        spotlightHotKey.register(.init(keyCode: HotKeyCodes.space,
                                       modifiers: HotKeyCodes.cmd | HotKeyCodes.option), id: 2)
        self.spotlightHotKey = spotlightHotKey
    }

    @objc private func toggleSpotlight() {
        guard let spotlight else { return }
        if spotlight.isVisible { spotlight.hide() }
        else { previousApp = NSWorkspace.shared.frontmostApplication; spotlight.show() }
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
            // Accessibility not granted: the content is already on the pasteboard
            // (copy-only fallback), so just paste manually with ⌘V. Prompt for
            // access at most once so we don't nag on every use.
            if !didPromptAccessibility {
                didPromptAccessibility = true
                _ = AccessibilityPermission.check(prompt: true)
            }
        }
    }
}
