import ApplicationServices
import Foundation

/// Accessibility permission used by paste-back (posting synthetic key events).
public enum AccessibilityPermission {
    /// Whether the app is currently trusted for Accessibility.
    public static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Checks trust and, if `prompt` is true, shows the system permission dialog.
    public static func check(prompt: Bool) -> Bool {
        // Value of kAXTrustedCheckOptionPrompt; referenced literally because the
        // CFString global is not concurrency-safe under Swift 6.
        let options = ["AXTrustedCheckOptionPrompt": prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}
