# Shelf

A native macOS clipboard manager — a keyboard-first, horizontal carousel of live
preview **cards** (not a text list) on a translucent glass shelf pinned to the
bottom of your screen. **Local-only**, **unsandboxed**, macOS 14+, built with
AppKit + SwiftUI and Swift 6 strict concurrency.

![Shelf — light](docs/screenshots/cards-light.png)
![Shelf — dark](docs/screenshots/cards-dark.png)

> Inspired by [Paste](https://pasteapp.io/), but an independent implementation:
> Shelf contains **no** code, assets, or measurements from it, and uses its own
> name, icon, geometry, palette, and design tokens.

## Features

### Capture & content types
- **Rich preview cards** per content type — text, rich text/HTML, code
  (syntax-highlighted), image (thumbnail + dimensions), video (QuickLook poster
  + duration), audio (artwork or waveform), link (og:image/favicon + title +
  domain), map (`MKMapSnapshotter`), color (swatch + hex), and files. Previews
  are generated off-main via QuickLook / AVFoundation and cached per item.
- **Automatic capture** — `DispatchSourceTimer` polls `NSPasteboard.changeCount`,
  classifies, SHA-256 dedups, and stores to CoreData.
- **OCR image search** — Vision recognizes text inside screenshots/images at
  capture; that text is indexed so images are findable by their contents.

### Find
- **Power Search** — fuzzy, typo-tolerant matching with intelligent ranking
  (prefix › substring › fuzzy, then recency). Searches text, titles, OCR text,
  and URLs across **all** pinboards.
- **Filters** — narrow by content **type**, source **app**, **date** (today /
  7 / 30 days), and **pinboard**, shown as removable visual tokens.
- **Jump to History** — from any search result, **Show in Clipboard / Show in
  Pinboard** (or **⌘G**) reveals the item in its collection, in context.

### Organize
- **Collections (pinboards)** with color-coded headers; **drag a card onto a
  tab** to refile it; create with **＋**, delete via right-click → Delete.
- **Pin / Unpin** — pinned clips sort to the top (📌 badge).
- **Opt-in auto-categorization** — rules by content kind or text/regex route new
  clips into collections (default off; Clipboard History always shows all).
- **Clear All** and **lazy loading** (first 30, then page-in on scroll).

### Use an item
- **Paste-back** — restores all representations and posts a synthetic ⌘V into
  the previously-active app (Accessibility-gated; copy-only fallback otherwise).
- **Quick Look** — **Space** previews images/video/audio/PDF/files; **Esc** closes.
- **Edit** — rename a clip and edit plain text in place.
- **Plain-text paste** — hold **Option** (or “Paste without Formatting”).
- **Copy / drag as file** — paste images into any app or webpage as a file.
- **Rotate image**, **Open link** (**⌘O**), and **Share…** (system share sheet).
- **New Text Item** — create a clip from scratch with **⌘N**.

### Privacy
- **Show during screen sharing** toggle — hide Shelf from recording, sharing,
  and screenshots (`NSWindow.sharingType`).
- **Ignore confidential content** — skip items apps mark confidential (passwords).

### Feel
- **Keyboard-first** — ⇧⌘V to summon, ← → to move, ⌘1–9 to pick + paste, ⏎ to
  paste, ⎋ to dismiss, Space to preview, ⌘G jump, ⌘N new, ⌘O open.
- **Native materials** — real `NSVisualEffectView` glass that blurs the desktop
  and tracks light/dark; layered shadows; continuous corners.
- **Accessible** — WCAG AA header contrast, VoiceOver labels, and full support
  for Reduce Transparency / Reduce Motion / Increase Contrast.

### Menu bar
Show Shelf · New Text Item (⌘N) · Pause/Resume Capture (⌘P) · Clear All History ·
Settings (Privacy, Auto-Categorization) · About · Help · Quit.

## How it works

Capture → classify → dedup → store → render → paste-back:

- **Capture:** a `DispatchSourceTimer` (~0.3 s) polls `NSPasteboard.changeCount`,
  classifies the content, SHA-256 dedups, and writes to CoreData. Skips
  `org.nspasteboard.ConcealedType` / `TransientType` and ignored bundle IDs.
- **Activation:** menu-bar `NSStatusItem` + global hotkey **⇧⌘V** (Carbon
  `RegisterEventHotKey`). Agent app (`LSUIElement`), no Dock icon. The panel is a
  non-activating floating `NSPanel` pinned flush to the screen bottom.

Not implemented (needs frameworks out of scope for this build): CloudKit sync /
shared pinboards, in-app web browser link editing, iPhone document scanning
(Continuity Camera), and Shortcuts / App Intents automation.

## Project layout

```
Package.swift            Root SPM executable → depends on the three local packages
App/                     Xcode-less app target
  main.swift             NSApplication bootstrap (.accessory policy)
  AppDelegate.swift      Status item, hotkey, panel toggle, paste-back wiring
  AppEnvironment.swift   Composition root (no global singletons)
  PanelController.swift  NSPanel + SwiftUI host + key monitor
Packages/
  Core/                  UI-free, platform-free, unit-tested
    Model, Pasteboard protocols, Classifier, Fingerprint (SHA-256),
    CoreDataModel (programmatic), PersistentStore, Repository, CaptureManager
    Tests/CoreTests      classification, dedup, capture (with a mock pasteboard)
  Platform/              NSPasteboard I/O, CGEvent paste-back, Carbon hotkey, AX
  UI/                    Theme (all tunable constants), cards, carousel, view model
Resources/
  Info.plist             LSUIElement, NSPasteboardUsageDescription
  Shelf.entitlements app-sandbox = false (unsandboxed direct build)
Makefile                 build / bundle / sign / run / test
```

**Tunable constants** live in `Packages/UI/Sources/UI/Theme.swift` — card width/
height/radius/spacing, blur material + tint, selection scale/shadow, and spring
timing. Adjust there to tune feel against the reference app.

## Install

### Homebrew (recommended)

```bash
brew tap yindia/shelf https://github.com/yindia/shelf
brew install --cask shelf
```

Upgrades: `brew upgrade --cask shelf`. The cask clears the Gatekeeper quarantine
flag automatically (the build is ad-hoc signed, not notarized).

### Direct download

Grab **Shelf.dmg** from the [latest release](../../releases/latest), open it, and
drag **Shelf** to Applications.

> Builds are **ad-hoc signed, not notarized**, so Gatekeeper warns on first run.
> Right-click **Shelf.app → Open** once, or run
> `xattr -dr com.apple.quarantine /Applications/Shelf.app`. Grant **Accessibility**
> when prompted (needed for paste-back).

To cut a release, push a tag — CI builds and attaches the DMG:

```bash
git tag v0.1.0 && git push origin v0.1.0
```

## Requirements

- **Xcode 16+** (ships the Swift 6.2 toolchain) **or** the standalone Swift 6
  toolchain. Verify: `swift --version` → `6.x`.
- macOS 14 or newer.
- **No paid Apple Developer account** needed for local runs — the Makefile
  ad-hoc-signs (`codesign --sign -`). An account is required only later for
  **notarization / distribution** outside your own machine.

## Build & run

SPM resolves the three local packages by relative path — no network fetch.

```bash
# unit tests (Core)
make test            # or: cd Packages/Core && swift test

# build, bundle into Shelf.app, ad-hoc sign, and launch
make run
```

Or open in Xcode: `File ▸ Open…` the root **`Package.swift`**. Xcode resolves the
local packages automatically. (Xcode's SPM runner won't apply the Info.plist /
agent behavior — use `make run` for the real `.app`.)

Artifacts land in `build/Shelf.app`.

## First launch — what to grant

1. A **Shelf** icon appears in the menu bar (no Dock icon by design).
2. macOS shows an **Accessibility** permission prompt (Shelf requests it on
   launch, and again if you try to paste before granting). Paste-back posts a
   synthetic ⌘V into other apps, which requires:
   **System Settings ▸ Privacy & Security ▸ Accessibility → enable Shelf.**
   Capture and the UI work without it; only paste-back needs it.
3. Copy a few things (text, an image, a color from a color picker), then press
   **⇧⌘V** (or use the menu-bar item) to open the carousel.

If you rebuild, macOS may require re-granting Accessibility because the ad-hoc
signature changes. A stable (Developer ID) signature avoids that — see below.

## Releases & distribution

- `make dmg` packages the built app into `build/Shelf.dmg` (drag-to-Applications).
- Pushing a `v*` tag runs `.github/workflows/release.yml`, which tests, builds,
  stamps the version into `Info.plist`, packages the DMG, and publishes a GitHub
  Release with auto-generated notes.

For a warning-free install outside your own machine you'll want a paid Apple
Developer account to sign with a **Developer ID Application** certificate and
**notarize** (`xcrun notarytool submit`) + **staple** the app/DMG. The current
workflow ships ad-hoc-signed builds; see the release notes for the Gatekeeper
workaround.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). CI (GitHub Actions) builds and runs the
Core tests on macOS for every PR.

## License

[MIT](LICENSE) © Shelf contributors.
