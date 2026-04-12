import AppKit
import ScreenCaptureKit

protocol ThumbnailProviding {
    @MainActor
    func loadThumbnail(for window: WindowEntry) async -> NSImage?
}

struct ThumbnailService: ThumbnailProviding {
    @MainActor
    func loadThumbnail(for window: WindowEntry) async -> NSImage? {
        guard
            let content = try? await SCShareableContent.current,
            let scWindow = content.windows.first(where: { $0.windowID == window.id })
        else {
            TaboraLogger.log("thumbnail", "No shareable window for id=\(window.id) title=\(window.displayTitle)")
            return nil
        }

        let filter = SCContentFilter(desktopIndependentWindow: scWindow)
        let configuration = SCStreamConfiguration()
        configuration.width = size_t(max(scWindow.frame.width, 1))
        configuration.height = size_t(max(scWindow.frame.height, 1))
        configuration.showsCursor = false

        if #available(macOS 14.0, *) {
            configuration.ignoreShadowsSingleWindow = true
            configuration.shouldBeOpaque = true
        }

        guard let cgImage = try? await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration) else {
            TaboraLogger.log("thumbnail", "Capture failed for id=\(window.id) title=\(window.displayTitle)")
            return nil
        }

        TaboraLogger.log(
            "thumbnail",
            "Captured id=\(window.id) title=\(window.displayTitle) size=\(cgImage.width)x\(cgImage.height)"
        )
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }
}

struct UITestThumbnailService: ThumbnailProviding {
    private let modesByID: [CGWindowID: UITestWindowSeed.ThumbnailMode]

    init(seeds: [UITestWindowSeed]) {
        modesByID = Dictionary(
            uniqueKeysWithValues: seeds.map { (CGWindowID($0.id), $0.thumbnailMode) }
        )
    }

    @MainActor
    func loadThumbnail(for window: WindowEntry) async -> NSImage? {
        try? await Task.sleep(for: .milliseconds(120))

        guard modesByID[window.id] == .success else {
            return nil
        }

        return NSImage.makeMockThumbnail(
            title: window.displayTitle,
            accentColor: NSColor(calibratedHue: CGFloat((window.id % 7)) / 7, saturation: 0.55, brightness: 0.92, alpha: 1)
        )
    }
}

private extension NSImage {
    static func makeMockThumbnail(title: String, accentColor: NSColor) -> NSImage {
        let size = NSSize(width: 480, height: 300)
        let image = NSImage(size: size)

        image.lockFocus()

        NSColor.windowBackgroundColor.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()

        accentColor.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 220, width: size.width, height: 80)).fill()

        let bodyRect = NSRect(x: 24, y: 28, width: size.width - 48, height: 160)
        let bodyPath = NSBezierPath(roundedRect: bodyRect, xRadius: 20, yRadius: 20)
        NSColor.controlBackgroundColor.setFill()
        bodyPath.fill()

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 28, weight: .semibold),
            .foregroundColor: NSColor.labelColor,
        ]
        let appAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 16, weight: .medium),
            .foregroundColor: NSColor.secondaryLabelColor,
        ]

        NSString(string: title).draw(
            in: NSRect(x: 32, y: 120, width: size.width - 64, height: 72),
            withAttributes: titleAttributes
        )

        NSString(string: "Preview").draw(
            in: NSRect(x: 32, y: 72, width: 120, height: 24),
            withAttributes: appAttributes
        )

        image.unlockFocus()
        return image
    }
}
