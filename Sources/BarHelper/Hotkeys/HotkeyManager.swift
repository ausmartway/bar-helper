import AppKit
import Carbon.HIToolbox

/// Registers global hotkeys via the Carbon `RegisterEventHotKey` API
/// (REQ-C07). Carbon remains the supported way to receive system-wide hotkeys
/// in a sandbox-friendly manner; there is no modern Swift replacement.
final class HotkeyManager {

    private struct Registration {
        let ref: EventHotKeyRef
        let handler: (HotkeyAction) -> Void
        let action: HotkeyAction
    }

    private var registrations: [UInt32: Registration] = [:]
    private var nextID: UInt32 = 1
    private var eventHandler: EventHandlerRef?

    private static let signature: OSType = {
        // Four-char code 'BARH'.
        let chars = "BARH".utf8.prefix(4)
        return chars.reduce(0) { ($0 << 8) + OSType($1) }
    }()

    init() {
        installEventHandler()
    }

    deinit {
        unregisterAll()
        if let eventHandler { RemoveEventHandler(eventHandler) }
    }

    /// Register a single binding. `handler` is invoked on the main thread when
    /// the hotkey fires.
    func register(_ binding: HotkeyBinding, handler: @escaping (HotkeyAction) -> Void) {
        let id = nextID
        nextID += 1

        let hotKeyID = EventHotKeyID(signature: HotkeyManager.signature, id: id)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            binding.keyCode,
            binding.modifiers,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &ref
        )

        guard status == noErr, let ref else { return }
        registrations[id] = Registration(ref: ref, handler: handler, action: binding.action)
    }

    func unregisterAll() {
        for registration in registrations.values {
            UnregisterEventHotKey(registration.ref)
        }
        registrations.removeAll()
    }

    // MARK: - Carbon event plumbing

    private func installEventHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        // Pass `self` through the Carbon C callback via an opaque pointer.
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(
            GetEventDispatcherTarget(),
            { _, eventRef, userData in
                guard let userData, let eventRef else { return noErr }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                manager.handleHotKeyEvent(eventRef)
                return noErr
            },
            1,
            &eventType,
            selfPtr,
            &eventHandler
        )
    }

    private func handleHotKeyEvent(_ event: EventRef) {
        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )
        guard status == noErr,
              let registration = registrations[hotKeyID.id] else { return }

        let handler = registration.handler
        let action = registration.action
        DispatchQueue.main.async {
            handler(action)
        }
    }
}
