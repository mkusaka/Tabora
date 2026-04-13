import AppKit
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

    init(frontmostApplicationProvider: any FrontmostApplicationProviding = WorkspaceFrontmostApplicationProvider()) {
        self.frontmostApplicationProvider = frontmostApplicationProvider
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

        let entries = windowList.compactMap(makeEntry)
        return Self.filter(entries, frontmostApplicationPID: frontmostApplicationProvider.frontmostApplicationPID)
    }

    static func filter(_ entries: [WindowEntry], frontmostApplicationPID: pid_t?) -> [WindowEntry] {
        guard let frontmostApplicationPID else {
            return entries
        }

        let filteredEntries = entries.filter { $0.pid == frontmostApplicationPID }
        return filteredEntries.isEmpty ? entries : filteredEntries
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
            appIcon: runningApp?.icon,
            thumbnail: nil
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

struct UITestWindowCatalogService: WindowCataloging {
    let seeds: [UITestWindowSeed]

    func snapshot() -> [WindowEntry] {
        seeds.map(WindowEntry.makeMock(seed:))
    }
}
