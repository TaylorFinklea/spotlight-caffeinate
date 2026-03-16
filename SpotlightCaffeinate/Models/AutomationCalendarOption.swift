import Foundation

struct AutomationCalendarOption: Identifiable, Equatable, Sendable {
    var id: String
    var title: String
    var sourceTitle: String?
}

enum AutomationCalendarAuthorizationState: Sendable {
    case notDetermined
    case granted
    case denied
}

enum AutomationPowerSource: String, Codable, CaseIterable, Identifiable, Sendable {
    case connected
    case disconnected

    var id: String { rawValue }

    var title: String {
        switch self {
        case .connected:
            return "Connected"
        case .disconnected:
            return "Disconnected"
        }
    }
}
