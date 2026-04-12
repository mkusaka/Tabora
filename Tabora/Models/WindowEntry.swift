import AppKit
import CoreGraphics

struct WindowEntry: Identifiable, Hashable {
    let id: CGWindowID
    let pid: pid_t
    let appName: String
    let bundleIdentifier: String?
    let title: String
    let bounds: CGRect
    let layer: Int
    let appIcon: NSImage?
    var thumbnail: NSImage?

    var displayTitle: String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedTitle.isEmpty ? appName : trimmedTitle
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
}
