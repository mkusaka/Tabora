import Carbon.HIToolbox
import Foundation

private let taboraHotKeySignature: OSType = 0x54414252

private func taboraHotKeyHandler(
    _: EventHandlerCallRef?,
    event: EventRef?,
    userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard
        let event,
        let userData
    else {
        return noErr
    }

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

    guard status == noErr, hotKeyID.signature == taboraHotKeySignature else {
        return noErr
    }

    let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
    Task { @MainActor in
        manager.handleHotKeyPressed()
    }

    return noErr
}

final class HotkeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let onPressed: () -> Void

    init(onPressed: @escaping () -> Void) {
        self.onPressed = onPressed
    }

    deinit {
        stop()
    }

    func start() {
        guard hotKeyRef == nil else {
            return
        }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let installStatus = InstallEventHandler(
            GetEventDispatcherTarget(),
            taboraHotKeyHandler,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &handlerRef
        )

        guard installStatus == noErr else {
            return
        }

        let hotKeyID = EventHotKeyID(signature: taboraHotKeySignature, id: 1)
        RegisterEventHotKey(
            UInt32(kVK_Tab),
            UInt32(optionKey),
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )
    }

    func stop() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }

        if let handlerRef {
            RemoveEventHandler(handlerRef)
            self.handlerRef = nil
        }
    }

    @MainActor
    fileprivate func handleHotKeyPressed() {
        onPressed()
    }
}
