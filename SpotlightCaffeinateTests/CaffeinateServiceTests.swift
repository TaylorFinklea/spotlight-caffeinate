import Foundation
import Testing

struct CaffeinateServiceTests {
    @Test
    func presetsSeedDefaultsWhenMissing() async throws {
        let harness = ServiceHarness()
        let presets = try await harness.service.presets()

        #expect(presets.map(\.name) == ["5m", "15m", "30m", "60m"])
        #expect(presets.allSatisfy { $0.isPinned })
        #expect(presets.allSatisfy { $0.powerMode == .full })
    }

    @Test
    func legacyStateFallsBackToFullMode() async throws {
        let harness = ServiceHarness()
        try harness.writeLegacyState(
            """
            {
              "pid" : 42,
              "startedAt" : "2001-01-01T00:00:00Z",
              "endsAt" : "2099-01-01T00:30:00Z",
              "minutes" : 30
            }
            """
        )
        harness.processController.runningPIDs.insert(42)
        harness.timeBox.now = ISO8601DateFormatter().date(from: "2099-01-01T00:10:00Z") ?? .now

        let snapshot = try await harness.service.status()

        #expect(snapshot.effectivePowerMode == .full)
        #expect(snapshot.presetName == nil)
    }

    @Test
    func powerModeMapsToExpectedArguments() {
        #expect(CaffeinateService.arguments(for: .display, seconds: 300) == ["-d", "-u", "-t", "300"])
        #expect(CaffeinateService.arguments(for: .system, seconds: 300) == ["-i", "-s", "-u", "-t", "300"])
        #expect(CaffeinateService.arguments(for: .full, seconds: 300) == ["-d", "-i", "-s", "-u", "-t", "300"])
    }

    @Test
    func extendingSessionPreservesStartAndUpdatesEndTime() async throws {
        let harness = ServiceHarness()
        harness.timeBox.now = Date(timeIntervalSinceReferenceDate: 1_000)

        let started = try await harness.service.start(minutes: 30, powerMode: .display, source: .app)
        harness.timeBox.now = Date(timeIntervalSinceReferenceDate: 1_600)
        let extended = try await harness.service.extend(minutes: 15, source: .cli)

        #expect(extended.startedAt == started.startedAt)
        #expect(extended.minutesRequested == 45)
        #expect(extended.endsAt == Date(timeIntervalSinceReferenceDate: 3_700))
        #expect(harness.processController.launchedArguments.count == 2)
        #expect(harness.processController.launchedArguments.last == ["-d", "-u", "-t", "2100"])
        let scheduled = await harness.notificationCenter.scheduledSnapshots
        #expect(scheduled.last?.minutesRequested == 45)
    }

    @Test
    func historyIsCappedAtTwentyEntries() async throws {
        let harness = ServiceHarness()

        for index in 0..<25 {
            harness.timeBox.now = Date(timeIntervalSinceReferenceDate: TimeInterval(index * 120))
            _ = try await harness.service.start(minutes: 1, source: .cli)
            harness.timeBox.now = Date(timeIntervalSinceReferenceDate: TimeInterval(index * 120 + 30))
            _ = try await harness.service.stop()
        }

        let history = try await harness.service.recentSessions(limit: 50)

        #expect(history.count == 20)
        #expect(history.first?.source == .cli)
        #expect(history.last?.endedAt == Date(timeIntervalSinceReferenceDate: 630))
    }

    @Test
    func presetLookupByNameIsCaseInsensitive() async throws {
        let harness = ServiceHarness()
        _ = try await harness.service.createPreset(name: "Deep Work", minutes: 45, powerMode: .system, isPinned: true)

        let snapshot = try await harness.service.startPreset(named: "deep work", source: .spotlight)

        #expect(snapshot.presetName == "Deep Work")
        #expect(snapshot.effectivePowerMode == .system)
    }
}

private final class FakeProcessController: @unchecked Sendable, CaffeinateProcessControlling {
    var nextPID: Int32 = 100
    var launchedArguments: [[String]] = []
    var terminatedPIDs: [Int32] = []
    var runningPIDs: Set<Int32> = []

    func launch(arguments: [String]) throws -> Int32 {
        launchedArguments.append(arguments)
        let pid = nextPID
        nextPID += 1
        runningPIDs.insert(pid)
        return pid
    }

    func terminate(pid: Int32) throws {
        terminatedPIDs.append(pid)
        runningPIDs.remove(pid)
    }

    func isRunning(pid: Int32) -> Bool {
        runningPIDs.contains(pid)
    }
}

private actor FakeNotificationCenter: CaffeinateNotificationScheduling {
    private(set) var scheduledSnapshots: [CaffeinateSnapshot] = []
    private(set) var cancelCount = 0

    func scheduleCompletionNotificationIfNeeded(for snapshot: CaffeinateSnapshot) async {
        scheduledSnapshots.append(snapshot)
    }

    func cancelPendingCompletionNotification() async {
        cancelCount += 1
    }
}

private final class TimeBox: @unchecked Sendable {
    var now = Date(timeIntervalSinceReferenceDate: 0)
}

private struct ServiceHarness {
    let baseDirectory: URL
    let processController: FakeProcessController
    let notificationCenter: FakeNotificationCenter
    let timeBox: TimeBox
    let service: CaffeinateService

    init() {
        let baseDirectory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let processController = FakeProcessController()
        let notificationCenter = FakeNotificationCenter()
        let timeBox = TimeBox()

        self.baseDirectory = baseDirectory
        self.processController = processController
        self.notificationCenter = notificationCenter
        self.timeBox = timeBox
        service = CaffeinateService(
            baseDirectory: baseDirectory,
            notificationService: notificationCenter,
            processController: processController,
            now: { timeBox.now }
        )
    }

    func writeLegacyState(_ contents: String) throws {
        let directory = baseDirectory.appending(path: "SpotlightCaffeinate", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard let data = contents.data(using: .utf8) else {
            throw NSError(domain: "ServiceHarness", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not encode legacy state JSON."])
        }

        try data.write(to: directory.appending(path: "state.json"))
    }
}
