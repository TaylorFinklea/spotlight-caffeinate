import Foundation
import Testing

struct CaffeinateStatusFormatterTests {
    @Test
    func renderStatusIncludesActiveTimingAndPid() {
        let snapshot = CaffeinateSnapshot(
            state: .active,
            pid: 777,
            startedAt: Date(timeIntervalSinceReferenceDate: 0),
            endsAt: Date(timeIntervalSinceReferenceDate: 1_800),
            minutesRequested: 30,
            powerMode: .system,
            presetID: UUID(uuidString: "00000000-0000-0000-0000-000000000777"),
            presetName: "Deep Work",
            source: .cli,
            automationRuleID: UUID(uuidString: "00000000-0000-0000-0000-000000000999"),
            automationRuleName: "Morning Start"
        )

        let rendered = CaffeinateStatusFormatter.renderStatus(
            snapshot,
            now: Date(timeIntervalSinceReferenceDate: 900),
            formatTimestamp: fixedTimestamp
        )

        #expect(
            rendered
                ==
                """
                State: running
                Remaining: 15m
                Started: T+0
                Ending: T+1800
                Mode: system
                Preset: Deep Work
                Source: cli
                Automation: Morning Start
                PID: 777
                """
        )
    }

    @Test
    func renderStatusIncludesIdleDefaults() {
        let rendered = CaffeinateStatusFormatter.renderStatus(
            .inactive,
            now: Date(timeIntervalSinceReferenceDate: 900),
            formatTimestamp: fixedTimestamp
        )

        #expect(
            rendered
                ==
                """
                State: idle
                Remaining: 0s
                Started: -
                Ending: -
                Mode: -
                Preset: -
                Source: -
                Automation: -
                PID: -
                """
        )
    }

    @Test
    func renderWatchScreenWrapsStatusBlock() {
        let snapshot = CaffeinateSnapshot(
            state: .active,
            pid: 777,
            startedAt: Date(timeIntervalSinceReferenceDate: 0),
            endsAt: Date(timeIntervalSinceReferenceDate: 1_800),
            minutesRequested: 30,
            powerMode: .full,
            presetID: nil,
            presetName: nil,
            source: .app,
            automationRuleID: nil,
            automationRuleName: nil
        )

        let rendered = CaffeinateStatusFormatter.renderWatchScreen(
            snapshot,
            now: Date(timeIntervalSinceReferenceDate: 900),
            formatTimestamp: fixedTimestamp,
            includeClearScreen: false
        )

        #expect(rendered.contains("Spotlight Caffeinate CLI"))
        #expect(rendered.contains("State: running"))
        #expect(rendered.contains("Ending: T+1800"))
        #expect(rendered.contains("Mode: full"))
        #expect(rendered.contains("Press Ctrl-C to stop watching."))
        #expect(!rendered.contains("\u{001B}[2J"))
    }
}

private func fixedTimestamp(_ date: Date) -> String {
    "T+\(Int(date.timeIntervalSinceReferenceDate.rounded()))"
}
