import Foundation

enum TaboraLogger {
    static func log(_ category: String, _ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        print("[Tabora][\(timestamp)][\(category)] \(message)")
        fflush(stdout)
    }
}
