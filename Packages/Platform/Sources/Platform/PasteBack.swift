import AppKit
import Core
import Foundation

/// Restores an item to the pasteboard and pastes it into the previously-active app.
///
/// Flow: reactivate the prior frontmost app → write blobs (marked synthetic) →
/// post a synthetic ⌘V via `CGEvent`. Gated on Accessibility trust.
@MainActor
public final class PasteBack {
    private let pasteboard: PasteboardWriting
    /// Virtual key code for "V" on the ANSI layout.
    private let keyV: CGKeyCode = 0x09

    public init(pasteboard: PasteboardWriting) {
        self.pasteboard = pasteboard
    }

    public enum PasteError: Error {
        case accessibilityNotTrusted
    }

    /// Writes `representations`, reactivates `targetApp`, then sends ⌘V.
    /// Returns the fingerprint written so the caller can suppress re-capture.
    @discardableResult
    public func paste(
        _ representations: [CapturedRepresentation],
        to targetApp: NSRunningApplication?
    ) throws -> String {
        // Always copy to the pasteboard first, so an untrusted app still gets a
        // copy-only fallback the user can paste manually.
        pasteboard.write(representations, markSynthetic: true)
        let fingerprint = Fingerprint.make(representations)

        guard AccessibilityPermission.isTrusted else { throw PasteError.accessibilityNotTrusted }

        targetApp?.activate()

        // Give the target a beat to become frontmost, then paste.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [keyV] in
            Self.postCommandKey(keyV)
        }
        return fingerprint
    }

    private static func postCommandKey(_ key: CGKeyCode) {
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return }
        let down = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
