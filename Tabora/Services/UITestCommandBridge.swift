import Foundation

enum UITestCommand: String {
    case cycleForward
    case cycleBackward
    case cancel
    case confirm
}

enum UITestCommandBridge {
    static let commandFileEnvironmentKey = "UITEST_COMMAND_FILE"
}
