import Foundation
import Testing

struct RecentSessionEntryTests {
    @Test
    func summaryLineIncludesDurationModeAndSource() {
        let entry = RecentSessionEntry(
            id: UUID(),
            startedAt: Date(timeIntervalSinceReferenceDate: 0),
            endedAt: Date(timeIntervalSinceReferenceDate: 600),
            minutesRequested: 10,
            powerMode: .full,
            presetID: nil,
            presetName: "Focus",
            source: .automation,
            automationRuleID: nil,
            automationRuleName: nil
        )

        #expect(entry.summaryLine == "10m • Full • Automation")
    }
}
