import Foundation
import Testing

struct CaffeinateSnapshotTests {
    @Test
    func totalDurationUsesStartedAndEndDates() {
        let startedAt = Date(timeIntervalSinceReferenceDate: 1_000)
        let endsAt = Date(timeIntervalSinceReferenceDate: 2_800)
        let snapshot = CaffeinateSnapshot(
            state: .active,
            pid: 42,
            startedAt: startedAt,
            endsAt: endsAt,
            minutesRequested: 30
        )

        #expect(snapshot.totalDuration == 1_800)
    }

    @Test(arguments: remainingFractionCases)
    func remainingFractionClampsAndFallsBack(_ testCase: RemainingFractionCase) {
        let snapshot = CaffeinateSnapshot(
            state: testCase.state,
            pid: 42,
            startedAt: testCase.startedAt,
            endsAt: testCase.endsAt,
            minutesRequested: 30
        )

        #expect(snapshot.remainingFraction(at: testCase.now) == testCase.expectedFraction)
    }

    @Test
    func remainingTextRoundsDownToSeconds() {
        let startedAt = Date(timeIntervalSinceReferenceDate: 0)
        let endsAt = Date(timeIntervalSinceReferenceDate: 125)
        let snapshot = CaffeinateSnapshot(
            state: .active,
            pid: 42,
            startedAt: startedAt,
            endsAt: endsAt,
            minutesRequested: 2
        )

        #expect(snapshot.remainingText(at: Date(timeIntervalSinceReferenceDate: 0)) == "2m 5s")
        #expect(snapshot.remainingText(at: Date(timeIntervalSinceReferenceDate: 65)) == "1m")
        #expect(snapshot.remainingText(at: Date(timeIntervalSinceReferenceDate: 125)) == "0s")
    }
}

struct RemainingFractionCase: Sendable {
    let state: CaffeinateSnapshot.State
    let startedAt: Date?
    let endsAt: Date?
    let now: Date
    let expectedFraction: Double
}

let remainingFractionCases: [RemainingFractionCase] = [
    RemainingFractionCase(
        state: .active,
        startedAt: Date(timeIntervalSinceReferenceDate: 0),
        endsAt: Date(timeIntervalSinceReferenceDate: 1_800),
        now: Date(timeIntervalSinceReferenceDate: 900),
        expectedFraction: 0.5
    ),
    RemainingFractionCase(
        state: .active,
        startedAt: Date(timeIntervalSinceReferenceDate: 0),
        endsAt: Date(timeIntervalSinceReferenceDate: 1_800),
        now: Date(timeIntervalSinceReferenceDate: -120),
        expectedFraction: 1
    ),
    RemainingFractionCase(
        state: .active,
        startedAt: Date(timeIntervalSinceReferenceDate: 0),
        endsAt: Date(timeIntervalSinceReferenceDate: 1_800),
        now: Date(timeIntervalSinceReferenceDate: 1_900),
        expectedFraction: 0
    ),
    RemainingFractionCase(
        state: .active,
        startedAt: nil,
        endsAt: nil,
        now: Date(timeIntervalSinceReferenceDate: 900),
        expectedFraction: 1
    ),
    RemainingFractionCase(
        state: .active,
        startedAt: Date(timeIntervalSinceReferenceDate: 1_800),
        endsAt: Date(timeIntervalSinceReferenceDate: 0),
        now: Date(timeIntervalSinceReferenceDate: 900),
        expectedFraction: 1
    ),
    RemainingFractionCase(
        state: .inactive,
        startedAt: Date(timeIntervalSinceReferenceDate: 0),
        endsAt: Date(timeIntervalSinceReferenceDate: 1_800),
        now: Date(timeIntervalSinceReferenceDate: 900),
        expectedFraction: 0
    )
]
