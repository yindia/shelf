import AppKit
import Carbon.HIToolbox

/// A global ⌘V interceptor used while Paste Stack is active. On each ⌘V it calls
/// `onPaste` (which writes the next stack item to the pasteboard) and then lets
/// the keystroke pass through unchanged, so the frontmost app pastes that item.
///
/// Requires Accessibility trust (same as paste-back). Only runs while the stack
/// is active; `stop()` tears the tap down completely.
public final class PasteStackTap {
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    /// Called on the main thread for each ⌘V. Returns true if an item was staged
    /// (otherwise the ⌘V is left to paste whatever is already on the clipboard).
    private let onPaste: () -> Bool

    public init(onPaste: @escaping () -> Bool) {
        self.onPaste = onPaste
    }

    /// Whether a tap can be created (Accessibility granted).
    public static var isSupported: Bool { AXIsProcessTrusted() }

    public func start() {
        guard tap == nil else { return }
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let me = Unmanaged<PasteStackTap>.fromOpaque(refcon).takeUnretainedValue()
                return me.handle(type: type, event: event)
            },
            userInfo: refcon
        ) else { return }

        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        self.source = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    public func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil
        source = nil
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Re-enable if the system disabled the tap (timeout / heavy input).
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        if type == .keyDown {
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            let flags = event.flags
            let isPlainCmdV = keyCode == kVK_ANSI_V
                && flags.contains(.maskCommand)
                && !flags.contains(.maskShift)
                && !flags.contains(.maskAlternate)
                && !flags.contains(.maskControl)
            if isPlainCmdV {
                _ = onPaste()   // stage next item onto the pasteboard; paste proceeds
            }
        }
        return Unmanaged.passUnretained(event)
    }
}
