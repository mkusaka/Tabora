import AppKit
import CoreGraphics
import UniformTypeIdentifiers

struct UITestWindowSeed: Codable, Hashable {
    enum ThumbnailMode: String, Codable {
        case success
        case missing
    }

    let id: UInt32
    let pid: Int32
    let appName: String
    let bundleIdentifier: String?
    let title: String
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat
    let layer: Int
    let thumbnailMode: ThumbnailMode

    var bounds: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }

    static func decodeEnvironmentJSON(_ json: String?) -> [UITestWindowSeed] {
        guard
            let json,
            let data = json.data(using: .utf8),
            let seeds = try? JSONDecoder().decode([UITestWindowSeed].self, from: data)
        else {
            return defaultSeeds
        }

        return seeds
    }

    static let defaultSeeds: [UITestWindowSeed] = [
        UITestWindowSeed(
            id: 101,
            pid: 3001,
            appName: "Safari",
            bundleIdentifier: "com.apple.Safari",
            title: "Tabora Launch Plan",
            x: 100,
            y: 100,
            width: 1440,
            height: 900,
            layer: 0,
            thumbnailMode: .success
        ),
        UITestWindowSeed(
            id: 102,
            pid: 3002,
            appName: "Notes",
            bundleIdentifier: "com.apple.Notes",
            title: "AltTab Notes",
            x: 220,
            y: 140,
            width: 1280,
            height: 820,
            layer: 0,
            thumbnailMode: .success
        ),
        UITestWindowSeed(
            id: 103,
            pid: 3003,
            appName: "Terminal",
            bundleIdentifier: "com.apple.Terminal",
            title: "",
            x: 300,
            y: 180,
            width: 1200,
            height: 760,
            layer: 0,
            thumbnailMode: .missing
        ),
    ]
}

extension WindowEntry {
    static func makeMock(seed: UITestWindowSeed) -> WindowEntry {
        let icon = NSWorkspace.shared.icon(for: .application)
        icon.size = NSSize(width: 64, height: 64)

        return WindowEntry(
            id: CGWindowID(seed.id),
            pid: seed.pid,
            appName: seed.appName,
            bundleIdentifier: seed.bundleIdentifier,
            title: seed.title,
            bounds: seed.bounds,
            layer: seed.layer,
            appIcon: icon,
            thumbnail: nil
        )
    }
}
