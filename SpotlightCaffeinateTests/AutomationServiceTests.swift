import Foundation
import Testing

struct AutomationServiceTests {
    @Test
    func weeklyRuleFiresOnceAtScheduledMinute() async throws {
        let harness = AutomationHarness()
        let preset = try await harness.sessionService.presets()[1]
        harness.timeBox.now = mondayAt(hour: 9, minute: 0)

        let rules = try await harness.automationService.createRule(
            name: "Morning Work",
            presetID: preset.id,
            trigger: .weekly(
                WeeklyAutomationTrigger(
                    weekdays: [.monday],
                    hour: 9,
                    minute: 0
                )
            ),
            enabled: true
        )

        await harness.automationService.evaluateScheduleRules(at: harness.timeBox.now)
        await harness.automationService.evaluateScheduleRules(at: harness.timeBox.now)

        let snapshot = try await harness.sessionService.status()
        let history = try await harness.automationService.runHistory(limit: 10)

        #expect(snapshot.source == .automation)
        #expect(snapshot.automationRuleID == rules[0].id)
        #expect(snapshot.automationRuleName == "Morning Work")
        #expect(harness.processController.launchedArguments.count == 1)
        #expect(history.count == 1)
        #expect(history.first?.outcome == .started)
    }

    @Test
    func missedScheduleDoesNotReplayLater() async throws {
        let harness = AutomationHarness()
        let preset = try await harness.sessionService.presets()[0]

        _ = try await harness.automationService.createRule(
            name: "Early Start",
            presetID: preset.id,
            trigger: .weekly(
                WeeklyAutomationTrigger(
                    weekdays: [.monday],
                    hour: 9,
                    minute: 0
                )
            ),
            enabled: true
        )

        harness.timeBox.now = mondayAt(hour: 9, minute: 2)
        await harness.automationService.evaluateScheduleRules(at: harness.timeBox.now)

        let snapshot = try await harness.sessionService.status()
        #expect(!snapshot.isRunning(at: harness.timeBox.now))
        #expect(harness.processController.launchedArguments.isEmpty)
    }

    @Test
    func powerRuleStartsOnMatchingTransition() async throws {
        let harness = AutomationHarness()
        let preset = try await harness.sessionService.presets()[2]

        _ = try await harness.automationService.createRule(
            name: "Docked",
            presetID: preset.id,
            trigger: .power(.connected),
            enabled: true
        )

        harness.timeBox.now = mondayAt(hour: 11, minute: 30)
        await harness.automationService.evaluatePowerRules(for: .connected, at: harness.timeBox.now)

        let snapshot = try await harness.sessionService.status()
        #expect(snapshot.isRunning(at: harness.timeBox.now))
        #expect(snapshot.source == .automation)
    }

    @Test
    func calendarRuleFiresOnceWithLeadTime() async throws {
        let harness = AutomationHarness()
        let preset = try await harness.sessionService.presets()[1]
        harness.calendarStore.state = .granted
        harness.calendarStore.options = [
            AutomationCalendarOption(id: "work", title: "Work", sourceTitle: "iCloud")
        ]
        harness.calendarStore.eventsToReturn = [
            AutomationCalendarEvent(
                identifier: "event-1",
                title: "Daily Standup",
                startDate: mondayAt(hour: 10, minute: 5)
            )
        ]

        _ = try await harness.automationService.createRule(
            name: "Standup Prep",
            presetID: preset.id,
            trigger: .calendar(
                CalendarAutomationTrigger(
                    calendarIdentifiers: ["work"],
                    startsBeforeMinutes: 5,
                    titleContains: "Standup"
                )
            ),
            enabled: true
        )

        harness.timeBox.now = mondayAt(hour: 10, minute: 0)
        await harness.automationService.evaluateCalendarRules(at: harness.timeBox.now)
        await harness.automationService.evaluateCalendarRules(at: harness.timeBox.now)

        let snapshot = try await harness.sessionService.status()
        let history = try await harness.automationService.runHistory(limit: 10)

        #expect(snapshot.automationRuleName == "Standup Prep")
        #expect(harness.processController.launchedArguments.count == 1)
        #expect(history.first?.calendarEventID == "event-1")
    }

    @Test
    func activeSessionConflictLogsSkippedRun() async throws {
        let harness = AutomationHarness()
        let preset = try await harness.sessionService.presets()[0]
        harness.timeBox.now = mondayAt(hour: 13, minute: 0)

        _ = try await harness.sessionService.start(minutes: 30, source: .app)
        _ = try await harness.automationService.createRule(
            name: "Docked",
            presetID: preset.id,
            trigger: .power(.connected),
            enabled: true
        )

        harness.timeBox.now = mondayAt(hour: 13, minute: 0)
        await harness.automationService.evaluatePowerRules(for: .connected, at: harness.timeBox.now)

        let snapshot = try await harness.sessionService.status()
        let history = try await harness.automationService.runHistory(limit: 10)

        #expect(snapshot.source == .app)
        #expect(history.first?.outcome == .skippedAlreadyRunning)
        #expect(history.first?.message.contains("already running") == true)
    }

    @Test
    func automationHistoryIsCappedAtFiftyRecords() async throws {
        let harness = AutomationHarness()
        let preset = try await harness.sessionService.presets()[0]
        _ = try await harness.automationService.createRule(
            name: "Docked",
            presetID: preset.id,
            trigger: .power(.connected),
            enabled: true
        )

        for index in 0..<55 {
            harness.timeBox.now = mondayAt(hour: 14, minute: index)
            await harness.automationService.evaluatePowerRules(for: .connected, at: harness.timeBox.now)
            _ = try await harness.sessionService.stop()
        }

        let history = try await harness.automationService.runHistory(limit: 100)
        #expect(history.count == 50)
    }
}

private final class AutomationFakeProcessController: @unchecked Sendable, CaffeinateProcessControlling {
    var nextPID: Int32 = 100
    var launchedArguments: [[String]] = []
    var terminatedPIDs: [Int32] = []
    var terminatedAssertionGroups: [[UInt32]] = []
    var runningPIDs: Set<Int32> = []

    func launch(arguments: [String]) throws -> CaffeinateLaunchResult {
        launchedArguments.append(arguments)
        let assertionCount = assertionCount(for: arguments)

        if assertionCount == 0 {
            let pid = nextPID
            nextPID += 1
            runningPIDs.insert(pid)
            return CaffeinateLaunchResult(pid: pid, assertionIDs: nil)
        }

        let assertionIDs = (0..<assertionCount).map { offset in
            UInt32(nextPID + Int32(offset))
        }
        let primaryID = Int32(assertionIDs[0])
        nextPID += Int32(assertionCount)
        runningPIDs.insert(primaryID)
        return CaffeinateLaunchResult(pid: primaryID, assertionIDs: assertionIDs)
    }

    func terminate(pid: Int32) throws {
        terminatedPIDs.append(pid)
        runningPIDs.remove(pid)
    }

    func terminate(assertionIDs: [UInt32]) throws {
        terminatedAssertionGroups.append(assertionIDs)

        if let primaryID = assertionIDs.first {
            runningPIDs.remove(Int32(primaryID))
        }
    }

    func isRunning(pid: Int32) -> Bool {
        runningPIDs.contains(pid)
    }

    private func assertionCount(for arguments: [String]) -> Int {
        guard let flags = arguments.first, flags.hasPrefix("-") else {
            return 0
        }

        var count = 0
        if flags.contains("d") { count += 1 }
        if flags.contains("i") || flags.contains("s") { count += 1 }
        if flags.contains("u") { count += 1 }
        return count
    }
}

private actor AutomationFakeNotificationCenter: CaffeinateNotificationScheduling {
    func scheduleCompletionNotificationIfNeeded(for snapshot: CaffeinateSnapshot) async {}
    func cancelPendingCompletionNotification() async {}
}

private final class AutomationTimeBox: @unchecked Sendable {
    var now = mondayAt(hour: 9, minute: 0)
}

private final class FakeAutomationCalendarStore: @unchecked Sendable, AutomationCalendarStoreControlling {
    var state: AutomationCalendarAuthorizationState = .granted
    var options: [AutomationCalendarOption] = []
    var eventsToReturn: [AutomationCalendarEvent] = []

    func authorizationState() -> AutomationCalendarAuthorizationState {
        state
    }

    func requestAccess() async throws -> Bool {
        state = .granted
        return true
    }

    func calendars() -> [AutomationCalendarOption] {
        options
    }

    func events(
        in calendarIdentifiers: [String],
        startingBetween startDate: Date,
        and endDate: Date
    ) -> [AutomationCalendarEvent] {
        eventsToReturn.filter { event in
            event.startDate >= startDate && event.startDate < endDate
        }
    }
}

private struct AutomationHarness {
    let baseDirectory: URL
    let processController: AutomationFakeProcessController
    let sessionService: CaffeinateService
    let automationService: AutomationService
    let calendarStore: FakeAutomationCalendarStore
    let timeBox: AutomationTimeBox

    init() {
        let baseDirectory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let processController = AutomationFakeProcessController()
        let notificationCenter = AutomationFakeNotificationCenter()
        let calendarStore = FakeAutomationCalendarStore()
        let timeBox = AutomationTimeBox()

        self.baseDirectory = baseDirectory
        self.processController = processController
        self.calendarStore = calendarStore
        self.timeBox = timeBox
        sessionService = CaffeinateService(
            baseDirectory: baseDirectory,
            notificationService: notificationCenter,
            processController: processController,
            now: { timeBox.now }
        )
        automationService = AutomationService(
            baseDirectory: baseDirectory,
            sessionService: sessionService,
            calendarStore: calendarStore,
            now: { timeBox.now }
        )
    }
}

private func mondayAt(hour: Int, minute: Int) -> Date {
    var components = DateComponents()
    components.year = 2026
    components.month = 3
    components.day = 16
    components.hour = hour
    components.minute = minute
    components.second = 0
    let calendar = Calendar(identifier: .gregorian)
    components.timeZone = calendar.timeZone
    return calendar.date(from: components) ?? .now
}
