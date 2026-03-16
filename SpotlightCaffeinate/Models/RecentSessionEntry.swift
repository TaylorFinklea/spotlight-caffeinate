import Foundation

struct RecentSessionEntry: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var startedAt: Date
    var endedAt: Date
    var minutesRequested: Int
    var powerMode: PowerMode
    var presetID: UUID?
    var presetName: String?
    var source: CaffeinateSessionSource
    var automationRuleID: UUID?
    var automationRuleName: String?

    var displayName: String {
        if let presetName, !presetName.isEmpty {
            return presetName
        }

        return "\(minutesRequested)m Session"
    }
}
