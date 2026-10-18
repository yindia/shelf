# Contributing to Shelf

Thanks for your interest! Shelf is a small, native macOS clipboard manager built
with AppKit + SwiftUI. Contributions are welcome.

## Getting started

```bash
git clone <your-fork-url>
cd shelf
make test      # run Core unit tests
make run       # build, bundle into Shelf.app, ad-hoc sign, launch
```

Requirements: macOS 14+, Xcode 16+ (Swift 6.2) or the standalone Swift 6
toolchain (`swift --version` → 6.x). No paid Apple Developer account is needed
for local development.

## Project layout

See [README.md](README.md#project-layout). In short:

- `Packages/Core` — platform-free, UI-free, unit-tested logic (capture,
  classification, dedup, CoreData, auto-rules). **Add tests here.**
- `Packages/Platform` — macOS integration (NSPasteboard, CGEvent paste-back,
  Carbon hotkey, QuickLook/AVFoundation previews, Accessibility).
- `Packages/UI` — SwiftUI views + `Theme.swift` (all tunable constants).
- `App` — the executable target and composition root.

## Conventions

- **Swift 6, strict concurrency.** `@MainActor` on UI; `async`/`await`; no
  force-unwraps outside tests; prefer value types.
- **Keep `Core` free of AppKit/SwiftUI** so it stays unit-testable.
- **Dependency injection** — no global singletons for stateful services; wire
  them in `AppEnvironment`.
- **All visual/tunable values live in `Packages/UI/Sources/UI/Theme.swift`.**
- Formatting/linting: `.swiftformat` and `.swiftlint.yml` are committed; run
  SwiftFormat/SwiftLint before opening a PR.
- Commits: [Conventional Commits](https://www.conventionalcommits.org)
  (`feat:`, `fix:`, `refactor:`, `docs:`, `test:`, `chore:`).

## Before a PR

1. `make test` passes (add tests for new Core logic).
2. `swift build` is clean (no new warnings).
3. UI changes: include before/after screenshots (`swift run Snapshot` renders
   `build/cards-*.png`).
4. Accessibility: keep WCAG AA contrast and VoiceOver labels intact.

## Scope / non-goals

See the README. v1 is intentionally local-only; cloud sync, OCR, on-device LLM,
and similar are out of scope unless discussed in an issue first.

## Note on the reference app

Shelf is *inspired by* Paste (pasteapp.io) but contains **no** code, assets, or
measurements from it. Do not add any. The `Paste.app` binary some contributors
keep locally for comparison is git-ignored and must never be committed.
