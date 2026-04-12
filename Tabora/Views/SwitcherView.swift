import SwiftUI

struct SwitcherView: View {
    @ObservedObject var state: SwitcherState

    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { scrollProxy in
                ZStack {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(.ultraThickMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.25), radius: 28, y: 16)

                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Tabora")
                                .font(.title2.weight(.bold))
                            Text("Window switcher MVP")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(alignment: .top, spacing: 20) {
                                ForEach(Array(state.entries.enumerated()), id: \.element.id) { index, entry in
                                    WindowItemView(
                                        entry: entry,
                                        isSelected: index == state.selectedIndex
                                    )
                                    .id(entry.id)
                                }
                            }
                            .padding(.vertical, 4)
                        }

                        if let overlayMessage = state.permissionStatus.overlayMessage {
                            Text(overlayMessage)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .accessibilityIdentifier("permission-banner")
                        }

                        HStack(spacing: 8) {
                            Text("Selected:")
                                .font(.callout.weight(.medium))
                            Text(state.selectedEntry?.displayTitle ?? "None")
                                .font(.callout)
                                .accessibilityIdentifier("selected-window-label")
                        }
                    }
                    .padding(28)
                }
                .frame(
                    width: preferredOverlayWidth(availableWidth: geometry.size.width),
                    height: preferredOverlayHeight(availableHeight: geometry.size.height)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier("switcher-overlay-root")
                .onAppear {
                    scrollToSelection(using: scrollProxy, animated: false)
                }
                .onChange(of: state.selectedIndex) { _, _ in
                    scrollToSelection(using: scrollProxy)
                }
                .onChange(of: state.entries.map(\.id)) { _, _ in
                    scrollToSelection(using: scrollProxy, animated: false)
                }
            }
        }
    }

    private func preferredOverlayWidth(availableWidth: CGFloat) -> CGFloat {
        min(max(availableWidth, 900), 1360)
    }

    private func preferredOverlayHeight(availableHeight: CGFloat) -> CGFloat {
        min(max(availableHeight, 420), 480)
    }

    private func scrollToSelection(using proxy: ScrollViewProxy, animated: Bool = true) {
        guard let selectedID = state.selectedEntry?.id else {
            return
        }

        let action = {
            proxy.scrollTo(selectedID, anchor: .center)
        }

        if animated {
            withAnimation(.easeInOut(duration: 0.18)) {
                action()
            }
        } else {
            action()
        }
    }
}
