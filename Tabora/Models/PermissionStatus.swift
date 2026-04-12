import Foundation

enum PermissionAccessState: String, Codable {
    case granted
    case missing
    case unknown
}

struct PermissionStatus: Equatable {
    let screenCapture: PermissionAccessState
    let accessibility: PermissionAccessState

    static let unknown = PermissionStatus(
        screenCapture: .unknown,
        accessibility: .unknown
    )

    var overlayMessage: String? {
        var parts: [String] = []

        if screenCapture == .missing {
            parts.append("Screen Recording permission is missing, so thumbnails may fall back to placeholders.")
        }

        if accessibility == .missing {
            parts.append("Accessibility permission is missing, so exact window focus may fall back to app activation.")
        }

        guard !parts.isEmpty else {
            return nil
        }

        return parts.joined(separator: " ")
    }
}
