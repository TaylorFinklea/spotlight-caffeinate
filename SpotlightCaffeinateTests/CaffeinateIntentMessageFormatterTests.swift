import Foundation
import Testing

struct CaffeinateIntentMessageFormatterTests {
    @Test
    func startDialogIncludesPresetAndMode() {
        let snapshot = CaffeinateSnapshot(
            state: .active,
            pid: 9,
            startedAt: Date(timeIntervalSinceReferenceDate: 0),
            endsAt: Date(timeIntervalSinceReferenceDate: 1_800),
            minutesRequested: 30,
            powerMode: .system,
            presetID: UUID(),
            presetName: "Deep Work",
            source: .spotlight,
            automationRuleID: nil,
            automationRuleName: nil
        )

        let rendered = CaffeinateIntentMessageFormatter.startDialog(for: snapshot, fallbackMinutes: 30)

        #expect(rendered.contains("started for 30 minutes"))
        #expect(rendered.contains("using Deep Work"))
        #expect(rendered.contains("in system mode"))
    }

    @Test
    func statusDialogReturnsIdleMessageWhenNotRunning() {
        #expect(CaffeinateIntentMessageFormatter.statusDialog(for: .inactive, now: .now) == "Caffeinate is not running.")
    }

    @Test
    func extendDialogPrefixesStatusMessage() {
        let snapshot = CaffeinateSnapshot(
            state: .active,
            pid: 9,
            startedAt: Date(timeIntervalSinceReferenceDate: 0),
            endsAt: Date(timeIntervalSinceReferenceDate: 2_700),
            minutesRequested: 45,
            powerMode: .full,
            presetID: nil,
            presetName: nil,
            source: .cli,
            automationRuleID: nil,
            automationRuleName: nil
        )

        let rendered = CaffeinateIntentMessageFormatter.extendDialog(
            for: snapshot,
            addedMinutes: 15,
            now: Date(timeIntervalSinceReferenceDate: 900)
        )

        #expect(rendered.contains("extended by 15 minutes"))
        #expect(rendered.contains("running with 30m remaining"))
    }

    @Test
    func statusDialogIncludesAutomationOrigin() {
        let snapshot = CaffeinateSnapshot(
            state: .active,
            pid: 9,
            startedAt: Date(timeIntervalSinceReferenceDate: 0),
            endsAt: Date(timeIntervalSinceReferenceDate: 2_700),
            minutesRequested: 45,
            powerMode: .full,
            presetID: UUID(),
            presetName: "Focus",
            source: .automation,
            automationRuleID: UUID(),
            automationRuleName: "Morning Work"
        )

        let rendered = CaffeinateIntentMessageFormatter.statusDialog(
            for: snapshot,
            now: Date(timeIntervalSinceReferenceDate: 900)
        )

        #expect(rendered.contains("from automation Morning Work"))
    }
}
