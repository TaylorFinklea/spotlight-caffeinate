import Foundation

enum AutomationRunOutcome: String, Codable, CaseIterable, Identifiable, Sendable {
    case started
    case skippedAlreadyRunning
    case skippedMissingPreset
    case skippedCalendarAccess
    case failed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .started:
            return "Started"
        case .skippedAlreadyRunning:
            return "Skipped"
        case .skippedMissingPreset:
            return "Missing Preset"
        case .skippedCalendarAccess:
            return "Calendar Access Needed"
        case .failed:
            return "Failed"
        }
    }

    var isError: Bool {
        switch self {
        case .started:
            return false
        case .skippedAlreadyRunning, .skippedMissingPreset, .skippedCalendarAccess, .failed:
            return true
        }
    }
}

struct AutomationRunRecord: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var ruleID: UUID
    var ruleName: String
    var firedAt: Date
    var outcome: AutomationRunOutcome
    var message: String
    var calendarEventID: String?
}
