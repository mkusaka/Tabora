import Foundation

struct UITestWindowSnapshot: Codable, Equatable {
    let id: UInt32
    let title: String
    let appName: String
    let hasThumbnail: Bool

    init(entry: WindowEntry) {
        id = UInt32(entry.id)
        title = entry.displayTitle
        appName = entry.appName
        hasThumbnail = entry.thumbnail != nil
    }
}
