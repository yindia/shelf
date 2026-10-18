import Carbon.HIToolbox
import Foundation

/// Registers a single global hotkey via the Carbon Events API (`RegisterEventHotKey`).
///
/// Carbon hotkeys work system-wide without Accessibility permission and are the
/// lightest option for a one-shot activation chord.
public final class HotKey {
    public struct Combo: Sendable {
        /// Carbon virtual key code (e.g. `kVK_ANSI_V`).
        public let keyCode: UInt32
        /// Carbon modifier mask (e.g. `cmdKey | shiftKey`).
        public let modifiers: UInt32
        public init(keyCode: UInt32, modifiers: UInt32) {
            self.keyCode = keyCode
            self.modifiers = modifiers
        }
    }

    private var ref: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private let onFire: @MainActor () -> Void
    private static let signature: OSType = 0x43_4C_50_53  // 'CLPS'

    /// Stored so the C callback can reach the Swift closure.
    private static let registry = Registry()

    public init(onFire: @escaping @MainActor () -> Void) {
        self.onFire = onFire
    }

    /// Installs the hotkey. Call once at startup.
    @MainActor
    public func register(_ combo: Combo, id: UInt32 = 1) {
        let hotKeyID = EventHotKeyID(signature: Self.signature, id: id)
        Self.registry.store(id: id, action: onFire)

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
            var firedID = EventHotKeyID()
            GetEventParameter(
                event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                nil, MemoryLayout<EventHotKeyID>.size, nil, &firedID
            )
            HotKey.registry.fire(id: firedID.id)
            return noErr
        }, 1, &eventType, nil, &handler)

        RegisterEventHotKey(combo.keyCode, combo.modifiers, hotKeyID, GetApplicationEventTarget(), 0, &ref)
    }

    @MainActor
    public func unregister() {
        if let ref { UnregisterEventHotKey(ref) }
        ref = nil
        if let handler { RemoveEventHandler(handler) }
        handler = nil
    }

    /// Bridges C hotkey callbacks (no context pointer) to Swift closures by id.
    private final class Registry: @unchecked Sendable {
        private let lock = NSLock()
        private var actions: [UInt32: @MainActor () -> Void] = [:]

        func store(id: UInt32, action: @escaping @MainActor () -> Void) {
            lock.withLock { actions[id] = action }
        }

        func fire(id: UInt32) {
            let action = lock.withLock { actions[id] }
            guard let action else { return }
            Task { @MainActor in action() }
        }
    }
}

/// Carbon key/modifier constants for the default activation chord.
public enum HotKeyCodes {
    public static let v = UInt32(kVK_ANSI_V)
    public static let space = UInt32(kVK_Space)
    public static let cmd = UInt32(cmdKey)
    public static let option = UInt32(optionKey)
    public static let shift = UInt32(shiftKey)
}
