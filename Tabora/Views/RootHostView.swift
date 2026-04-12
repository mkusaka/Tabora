import SwiftUI

struct RootHostView: View {
    let configuration: TaboraConfiguration
    @ObservedObject var state: SwitcherState
    let presentSwitcher: () -> Void

    var body: some View {
        Group {
            if configuration.isUITesting {
                TestingHostView(
                    state: state,
                    presentSwitcher: presentSwitcher
                )
            } else {
                HiddenHostView()
            }
        }
    }
}

private struct HiddenHostView: View {
    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .background(WindowHider())
    }
}

private struct WindowHider: NSViewRepresentable {
    func makeNSView(context _: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async { [weak view] in
            view?.window?.orderOut(nil)
        }
        return view
    }

    func updateNSView(_: NSView, context _: Context) {}
}

private struct TestingHostView: View {
    @ObservedObject var state: SwitcherState
    let presentSwitcher: () -> Void

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Tabora UI Test Harness")
                    .font(.title2.weight(.semibold))

                Text("This host window exists only for deterministic UI testing.")
                    .foregroundStyle(.secondary)

                Button("Present Switcher") {
                    presentSwitcher()
                }
                .accessibilityIdentifier("present-switcher-button")

                Text("Activation result")
                    .font(.headline)
                Text(state.activationSummary)
                    .accessibilityLabel(state.activationSummary)
                    .accessibilityIdentifier("activation-summary-label")

                if let overlayMessage = state.permissionStatus.overlayMessage {
                    Text(overlayMessage)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("host-permission-message")
                }

                if state.isVisible {
                    SwitcherView(state: state)
                        .accessibilityIdentifier("inline-switcher-host")
                }
            }
            .padding(24)
        }
        .frame(minWidth: 1200, minHeight: 900)
    }
}
