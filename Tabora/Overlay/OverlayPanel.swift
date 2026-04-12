import AppKit
import Carbon.HIToolbox

let backtabCharacter = "\u{19}"

func isTabNavigationEvent(_ event: NSEvent) -> Bool {
    Int(event.keyCode) == kVK_Tab
        || event.characters == "\t"
        || event.characters == backtabCharacter
        || event.charactersIgnoringModifiers == "\t"
}

func isBackwardTabNavigationEvent(_ event: NSEvent) -> Bool {
    event.characters == backtabCharacter
        || (isTabNavigationEvent(event) && event.modifierFlags.contains(.shift))
}

final class OverlayPanel: NSPanel {
    var onCycle: ((Bool) -> Void)?
    var onCancel: (() -> Void)?
    var onConfirm: (() -> Void)?
    var onModifierFlagsChanged: ((NSEvent.ModifierFlags) -> Void)?

    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        false
    }

    override func keyDown(with event: NSEvent) {
        if isTabNavigationEvent(event) {
            onCycle?(!isBackwardTabNavigationEvent(event))
        } else if Int(event.keyCode) == kVK_Escape {
            onCancel?()
        } else if [kVK_Return, kVK_ANSI_KeypadEnter, kVK_Space].contains(Int(event.keyCode)) {
            onConfirm?()
        } else {
            super.keyDown(with: event)
        }
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if isTabNavigationEvent(event) {
            onCycle?(!isBackwardTabNavigationEvent(event))
            return true
        } else if Int(event.keyCode) == kVK_Escape {
            onCancel?()
            return true
        } else if [kVK_Return, kVK_ANSI_KeypadEnter, kVK_Space].contains(Int(event.keyCode)) {
            onConfirm?()
            return true
        } else {
            return super.performKeyEquivalent(with: event)
        }
    }

    override func flagsChanged(with event: NSEvent) {
        onModifierFlagsChanged?(event.modifierFlags.intersection(.deviceIndependentFlagsMask))
        super.flagsChanged(with: event)
    }
}
