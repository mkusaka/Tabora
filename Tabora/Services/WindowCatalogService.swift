import AppKit
import ApplicationServices
import CoreGraphics

protocol WindowCataloging {
    func snapshot() -> [WindowEntry]
}

protocol FrontmostApplicationProviding {
    var frontmostApplicationPID: pid_t? { get }
}

struct WorkspaceFrontmostApplicationProvider: FrontmostApplicationProviding {
    var frontmostApplicationPID: pid_t? {
        NSWorkspace.shared.frontmostApplication?.processIdentifier
    }
}

struct WindowCatalogService: WindowCataloging {
    private let minimumWidth: CGFloat = 140
    private let minimumHeight: CGFloat = 90
    private let ignoredOwners: Set<String> = [
        "Dock",
        "Window Server",
        "Notification Center",
        "Control Center",
        "Spotlight",
    ]
    private let frontmostApplicationProvider: any FrontmostApplicationProviding
    private let minimizedWindowProvider: any MinimizedWindowProviding

    init(
        frontmostApplicationProvider: any FrontmostApplicationProviding = WorkspaceFrontmostApplicationProvider(),
        minimizedWindowProvider: any MinimizedWindowProviding = AccessibilityMinimizedWindowProvider()
    ) {
        self.frontmostApplicationProvider = frontmostApplicationProvider
        self.minimizedWindowProvider = minimizedWindowProvider
    }

    func snapshot() -> [WindowEntry] {
        guard
            let windowList = CGWindowListCopyWindowInfo(
                [.optionOnScreenOnly, .excludeDesktopElements],
                kCGNullWindowID
            ) as? [[String: Any]]
        else {
            return []
        }

        let onScreenEntries = windowList.compactMap(makeEntry)
        let frontmostApplicationPID = frontmostApplicationProvider.frontmostApplicationPID
        let minimizedEntries = frontmostApplicationPID.map(minimizedWindows(for:)) ?? []
        let entries = Self.merge(onScreenEntries: onScreenEntries, minimizedEntries: minimizedEntries)
        return Self.filter(entries, frontmostApplicationPID: frontmostApplicationPID)
    }

    static func filter(_ entries: [WindowEntry], frontmostApplicationPID: pid_t?) -> [WindowEntry] {
        guard let frontmostApplicationPID else {
            return entries
        }

        let filteredEntries = entries.filter { $0.pid == frontmostApplicationPID }
        return filteredEntries.isEmpty ? entries : filteredEntries
    }

    static func merge(onScreenEntries: [WindowEntry], minimizedEntries: [WindowEntry]) -> [WindowEntry] {
        let onScreenIDs = Set(onScreenEntries.map(\.id))
        return onScreenEntries + minimizedEntries.filter { !onScreenIDs.contains($0.id) }
    }

    private func makeEntry(from raw: [String: Any]) -> WindowEntry? {
        guard
            let layer = raw[kCGWindowLayer as String] as? Int,
            layer == 0,
            let ownerPID = raw[kCGWindowOwnerPID as String] as? pid_t,
            ownerPID != ProcessInfo.processInfo.processIdentifier,
            let boundsDictionary = raw[kCGWindowBounds as String] as? NSDictionary,
            let bounds = CGRect(dictionaryRepresentation: boundsDictionary),
            bounds.width >= minimumWidth,
            bounds.height >= minimumHeight
        else {
            return nil
        }

        let alpha = raw[kCGWindowAlpha as String] as? Double ?? 1
        guard alpha > 0.05 else {
            return nil
        }

        let ownerName = (raw[kCGWindowOwnerName as String] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown App"

        guard !ignoredOwners.contains(ownerName) else {
            return nil
        }

        let runningApp = NSRunningApplication(processIdentifier: ownerPID)
        let bundleIdentifier = runningApp?.bundleIdentifier

        guard bundleIdentifier != Bundle.main.bundleIdentifier else {
            return nil
        }

        let title = (raw[kCGWindowName as String] as? String) ?? ""
        if shouldRejectUntitledWindow(title: title, appName: ownerName, bundleIdentifier: bundleIdentifier) {
            return nil
        }

        return WindowEntry(
            id: CGWindowID(raw[kCGWindowNumber as String] as? UInt32 ?? 0),
            pid: ownerPID,
            appName: runningApp?.localizedName ?? ownerName,
            bundleIdentifier: bundleIdentifier,
            title: title,
            bounds: bounds,
            layer: layer,
            isMinimized: false,
            appIcon: runningApp?.icon,
            thumbnail: nil
        )
    }

    private func minimizedWindows(for processIdentifier: pid_t) -> [WindowEntry] {
        guard processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            return []
        }

        let runningApp = NSRunningApplication(processIdentifier: processIdentifier)
        let appName = runningApp?.localizedName ?? "Unknown App"
        let bundleIdentifier = runningApp?.bundleIdentifier

        guard
            bundleIdentifier != Bundle.main.bundleIdentifier,
            !ignoredOwners.contains(appName)
        else {
            return []
        }

        return minimizedWindowProvider.minimizedWindows(
            for: processIdentifier,
            appName: appName,
            bundleIdentifier: bundleIdentifier,
            appIcon: runningApp?.icon
        )
    }

    private func shouldRejectUntitledWindow(
        title: String,
        appName: String,
        bundleIdentifier: String?
    ) -> Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTitle.isEmpty {
            return false
        }

        guard let bundleIdentifier else {
            return false
        }

        if bundleIdentifier.hasPrefix("com.apple.") {
            return appName == "Dock" || appName == "Control Center"
        }

        return false
    }
}

protocol MinimizedWindowProviding {
    func minimizedWindows(
        for processIdentifier: pid_t,
        appName: String,
        bundleIdentifier: String?,
        appIcon: NSImage?
    ) -> [WindowEntry]
}

struct AccessibilityMinimizedWindowProvider: MinimizedWindowProviding {
    func minimizedWindows(
        for processIdentifier: pid_t,
        appName: String,
        bundleIdentifier: String?,
        appIcon: NSImage?
    ) -> [WindowEntry] {
        guard AXIsProcessTrusted() else {
            return []
        }

        let applicationElement = AXUIElementCreateApplication(processIdentifier)
        guard let windows = copyWindows(from: applicationElement) else {
            return []
        }

        return windows.enumerated().compactMap { index, windowElement in
            guard copyBoolAttribute(kAXMinimizedAttribute as CFString, from: windowElement) else {
                return nil
            }

            let title = copyStringAttribute(kAXTitleAttribute as CFString, from: windowElement) ?? ""
            let bounds = copyFrame(from: windowElement) ?? .zero

            return WindowEntry(
                id: syntheticWindowID(
                    processIdentifier: processIdentifier,
                    title: title,
                    bounds: bounds,
                    index: index
                ),
                pid: processIdentifier,
                appName: appName,
                bundleIdentifier: bundleIdentifier,
                title: title,
                bounds: bounds,
                layer: 0,
                isMinimized: true,
                appIcon: appIcon,
                thumbnail: nil
            )
        }
    }

    private func copyWindows(from applicationElement: AXUIElement) -> [AXUIElement]? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(applicationElement, kAXWindowsAttribute as CFString, &value)
        guard result == .success, let array = value as? [AXUIElement] else {
            return nil
        }
        return array
    }

    private func copyStringAttribute(_ attribute: CFString, from element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else {
            return nil
        }

        return value as? String
    }

    private func copyBoolAttribute(_ attribute: CFString, from element: AXUIElement) -> Bool {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else {
            return false
        }

        return (value as? NSNumber)?.boolValue ?? false
    }

    private func copyFrame(from element: AXUIElement) -> CGRect? {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?

        guard
            AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionValue) == .success,
            AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue) == .success,
            let positionValue,
            let sizeValue
        else {
            return nil
        }

        // AXUIElementCopyAttributeValue returns AXValue-backed CFTypeRefs for these attributes.
        // swiftlint:disable:next force_cast
        let positionAX = positionValue as! AXValue
        // swiftlint:disable:next force_cast
        let sizeAX = sizeValue as! AXValue

        var point = CGPoint.zero
        var size = CGSize.zero
        guard
            AXValueGetType(positionAX) == .cgPoint,
            AXValueGetType(sizeAX) == .cgSize,
            AXValueGetValue(positionAX, .cgPoint, &point),
            AXValueGetValue(sizeAX, .cgSize, &size)
        else {
            return nil
        }

        return CGRect(origin: point, size: size)
    }

    private func syntheticWindowID(
        processIdentifier: pid_t,
        title: String,
        bounds: CGRect,
        index: Int
    ) -> CGWindowID {
        var hash: UInt32 = 2_166_136_261

        func mix(_ byte: UInt8) {
            hash ^= UInt32(byte)
            hash = hash &* 16_777_619
        }

        func mix(_ value: Int64) {
            let unsigned = UInt64(bitPattern: value)
            for shift in stride(from: 0, through: 56, by: 8) {
                mix(UInt8((unsigned >> UInt64(shift)) & 0xFF))
            }
        }

        mix(Int64(processIdentifier))
        mix(Int64(index))
        mix(Int64(bounds.origin.x.rounded()))
        mix(Int64(bounds.origin.y.rounded()))
        mix(Int64(bounds.size.width.rounded()))
        mix(Int64(bounds.size.height.rounded()))
        title.utf8.forEach(mix)

        return CGWindowID(0x8000_0000 | (hash & 0x7FFF_FFFF))
    }
}

struct UITestWindowCatalogService: WindowCataloging {
    let seeds: [UITestWindowSeed]

    func snapshot() -> [WindowEntry] {
        seeds.map(WindowEntry.makeMock(seed:))
    }
}
