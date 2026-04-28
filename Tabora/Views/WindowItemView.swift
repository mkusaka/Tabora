import SwiftUI

struct WindowItemView: View {
    let entry: WindowEntry
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            thumbnailArea

            VStack(alignment: .leading, spacing: 8) {
                Text(entry.displayTitle)
                    .font(.headline)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .accessibilityIdentifier("window-title-\(entry.id)")

                HStack(spacing: 8) {
                    appIcon

                    Text(entry.appName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .accessibilityIdentifier("window-app-\(entry.id)")
                }

                Text(isSelected ? "selected" : "unselected")
                    .font(.caption2)
                    .foregroundStyle(.clear)
                    .accessibilityIdentifier("window-card-state-\(entry.id)")
            }
        }
        .padding(16)
        .frame(width: 260, height: 280, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.16) : Color.black.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(isSelected ? Color.accentColor : Color.white.opacity(0.08), lineWidth: isSelected ? 2 : 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("window-card-\(entry.id)")
        .accessibilityValue(isSelected ? "selected" : "unselected")
    }

    private var thumbnailArea: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.22))

            if let thumbnail = entry.thumbnail {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.black.opacity(0.32))
                    .padding(8)

                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .padding(8)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .accessibilityIdentifier("thumbnail-image-\(entry.id)")
            } else {
                VStack(spacing: 8) {
                    appIcon
                        .frame(width: 40, height: 40)

                    Text(entry.isMinimized ? "Minimized" : "No Preview")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(entry.isMinimized ? "Minimized" : "No Preview")
                .accessibilityIdentifier("thumbnail-placeholder-\(entry.id)")
            }
        }
        .frame(height: 160)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    @ViewBuilder
    private var appIcon: some View {
        if let appIcon = entry.appIcon {
            Image(nsImage: appIcon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24, height: 24)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .accessibilityIdentifier("app-icon-\(entry.id)")
        } else {
            Image(systemName: "app.dashed")
                .frame(width: 24, height: 24)
                .accessibilityIdentifier("app-icon-\(entry.id)")
        }
    }
}
