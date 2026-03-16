import Foundation
import Testing

struct CaffeinateCLIJSONFormatterTests {
    @Test
    func renderStatusIncludesStructuredFields() throws {
        let snapshot = CaffeinateSnapshot(
            state: .active,
            pid: 321,
            startedAt: Date(timeIntervalSinceReferenceDate: 0),
            endsAt: Date(timeIntervalSinceReferenceDate: 1_800),
            minutesRequested: 30,
            powerMode: .system,
            presetID: UUID(uuidString: "00000000-0000-0000-0000-000000000321"),
            presetName: "Deep Work",
            source: .cli,
            automationRuleID: UUID(uuidString: "00000000-0000-0000-0000-000000000654"),
            automationRuleName: "Morning Start"
        )

        let json = try CaffeinateCLIJSONFormatter.renderStatus(
            snapshot,
            now: Date(timeIntervalSinceReferenceDate: 900)
        )

        #expect(json.contains("\"state\" : \"running\""))
        #expect(json.contains("\"remainingSeconds\" : 900"))
        #expect(json.contains("\"powerMode\" : \"system\""))
        #expect(json.contains("\"presetName\" : \"Deep Work\""))
        #expect(json.contains("\"source\" : \"cli\""))
        #expect(json.contains("\"automationRuleName\" : \"Morning Start\""))
    }

    @Test
    func renderHistoryOutputsArray() throws {
        let history = [
            RecentSessionEntry(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000123")!,
                startedAt: Date(timeIntervalSinceReferenceDate: 0),
                endedAt: Date(timeIntervalSinceReferenceDate: 1_800),
                minutesRequested: 30,
                powerMode: .full,
                presetID: nil,
                presetName: "Focus",
                source: .app,
                automationRuleID: nil,
                automationRuleName: nil
            )
        ]

        let json = try CaffeinateCLIJSONFormatter.renderHistory(history)

        #expect(json.contains("\"presetName\" : \"Focus\""))
        #expect(json.contains("\"powerMode\" : \"full\""))
        #expect(json.contains("\"source\" : \"app\""))
    }

    @Test
    func renderAutomationsOutputsPresetNames() throws {
        let summaries = [
            AutomationRuleSummary(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000456")!,
                name: "Morning Work",
                enabled: true,
                presetID: UUID(uuidString: "00000000-0000-0000-0000-000000000789")!,
                presetName: "Deep Work",
                trigger: .power(.connected),
                createdAt: Date(timeIntervalSinceReferenceDate: 0),
                updatedAt: Date(timeIntervalSinceReferenceDate: 0),
                lastRunAt: nil
            )
        ]

        let json = try CaffeinateCLIJSONFormatter.renderAutomations(summaries)

        #expect(json.contains("\"name\" : \"Morning Work\""))
        #expect(json.contains("\"presetName\" : \"Deep Work\""))
    }
}
