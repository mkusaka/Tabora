import AppKit
import Carbon.HIToolbox
import SwiftUI

@MainActor
final class OverlayWindowController {
    private let panel: OverlayPanel
    private let hostingController: NSHostingController<SwitcherView>
    private var keyMonitor: Any?

    init(
        state: SwitcherState,
        onCycle: @escaping (Bool) -> Void,
        onCancel: @escaping () -> Void,
        onConfirm: @escaping () -> Void,
        onModifierFlagsChanged: @escaping (NSEvent.ModifierFlags) -> Void
    ) {
        hostingController = NSHostingController(rootView: SwitcherView(state: state))

        panel = OverlayPanel(
            contentRect: NSRect(x: 0, y: 0, width: 1180, height: 440),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.contentViewController = hostingController
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.identifier = NSUserInterfaceItemIdentifier("switcher-overlay-panel")
        panel.setAccessibilityIdentifier("switcher-overlay-panel")
        panel.onCycle = onCycle
        panel.onCancel = onCancel
        panel.onConfirm = onConfirm
        panel.onModifierFlagsChanged = onModifierFlagsChanged
    }

    func setVisible(_ visible: Bool) {
        if visible {
            show()
        } else {
            hide()
        }
    }

    private func show() {
        recenter()
        installKeyMonitorIfNeeded()
        NSApp.activate(ignoringOtherApps: true)
        panel.orderFrontRegardless()
        panel.makeKeyAndOrderFront(nil)
    }

    private func hide() {
        removeKeyMonitor()
        panel.orderOut(nil)
    }

    private func recenter() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            return
        }

        let contentSize = preferredPanelSize(for: screen)
        panel.setContentSize(contentSize)

        let frame = panel.frameRect(forContentRect: NSRect(origin: .zero, size: contentSize))
        let origin = NSPoint(
            x: screen.visibleFrame.midX - frame.width / 2,
            y: screen.visibleFrame.midY - frame.height / 2
        )
        panel.setFrameOrigin(origin)
    }

    private func installKeyMonitorIfNeeded() {
        guard keyMonitor == nil else {
            return
        }

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak panel] event in
            guard let panel, panel.isVisible else {
                return event
            }

            if isTabNavigationEvent(event) {
                panel.onCycle?(!isBackwardTabNavigationEvent(event))
                return nil
            } else if Int(event.keyCode) == kVK_Escape {
                panel.onCancel?()
                return nil
            } else if [kVK_Return, kVK_ANSI_KeypadEnter, kVK_Space].contains(Int(event.keyCode)) {
                panel.onConfirm?()
                return nil
            } else {
                return event
            }
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
    }

    private func preferredPanelSize(for screen: NSScreen) -> NSSize {
        let visibleFrame = screen.visibleFrame
        return NSSize(
            width: min(max(visibleFrame.width * 0.8, 960), 1360),
            height: min(max(visibleFrame.height * 0.42, 420), 480)
        )
    }
}
