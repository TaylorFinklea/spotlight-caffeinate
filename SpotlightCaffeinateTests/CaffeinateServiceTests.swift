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

    @Test
    func separateServiceInstancesCanStatusAndExtendTheSameSession() async throws {
        let harness = ServiceHarness()
        harness.timeBox.now = Date(timeIntervalSinceReferenceDate: 1_000)
        _ = try await harness.service.start(minutes: 30, powerMode: .full, source: .cli)

        let secondHarness = ServiceHarness(
            baseDirectory: harness.baseDirectory,
            processController: harness.processController,
            notificationCenter: harness.notificationCenter,
            timeBox: harness.timeBox
        )

        harness.timeBox.now = Date(timeIntervalSinceReferenceDate: 1_300)
        let status = try await secondHarness.service.status()
        #expect(status.state == .active)
        #expect(status.remainingSeconds(at: harness.timeBox.now) == 1_500)

        let extended = try await secondHarness.service.extend(minutes: 10, source: .cli)
        #expect(extended.state == .active)
        #expect(extended.minutesRequested == 40)
        #expect(harness.processController.terminatedAssertionGroups == [[100, 101, 102]])
        #expect(harness.processController.launchedArguments.count == 2)
        #expect(harness.processController.runningPIDs.contains(103))
    }

    @Test
    func cliCanRecoverFromLegacyCLIStateWithoutBackendMetadata() async throws {
        let harness = ServiceHarness(sessionBackend: .subprocess)
        try harness.writeLegacyState(
            """
            {
              "pid" : 1,
              "startedAt" : "2099-01-01T00:00:00Z",
              "endsAt" : "2099-01-01T01:00:00Z",
              "minutes" : 60,
              "powerMode" : "full",
              "source" : "cli"
            }
            """
        )
        harness.timeBox.now = ISO8601DateFormatter().date(from: "2099-01-01T00:10:00Z") ?? .now

        let snapshot = try await harness.service.status()
        #expect(snapshot.state == .inactive)

        let restarted = try await harness.service.start(minutes: 15, powerMode: .system, source: .cli)
        #expect(restarted.state == .active)
        #expect(restarted.minutesRequested == 15)
        #expect(restarted.effectivePowerMode == .system)
        #expect(restarted.pid == 100)
        #expect(harness.processController.launchedArguments.last == ["-i", "-s", "-u", "-t", "900"])
    }

    @Test
    func expiredAssertionSessionReleasesAssertionsBeforeArchiving() async throws {
        let harness = ServiceHarness()
        harness.timeBox.now = Date(timeIntervalSinceReferenceDate: 1_000)

        _ = try await harness.service.start(minutes: 1, powerMode: .full, source: .app)
        harness.timeBox.now = Date(timeIntervalSinceReferenceDate: 1_061)

        let snapshot = try await harness.service.status()
        let history = try await harness.service.recentSessions(limit: 5)

        #expect(snapshot.state == .inactive)
        #expect(harness.processController.terminatedAssertionGroups == [[100, 101, 102]])
        #expect(history.count == 1)
        #expect(history.first?.endedAt == Date(timeIntervalSinceReferenceDate: 1_060))
    }

    @Test
    func createPresetRejectsInvalidMinutes() async throws {
        let harness = ServiceHarness()

        for invalid in [0, 1_441] {
            do {
                _ = try await harness.service.createPreset(name: "Test", minutes: invalid, powerMode: .full, isPinned: false)
                Issue.record("Expected invalidMinutes for \(invalid)")
            } catch let error as CaffeinateServiceError {
                guard case .invalidMinutes = error else {
                    Issue.record("Expected .invalidMinutes, got \(error)")
                    continue
                }
            }
        }
    }

    @Test
    func createPresetRejectsEmptyName() async throws {
        let harness = ServiceHarness()

        for invalid in ["", "   "] {
            do {
                _ = try await harness.service.createPreset(name: invalid, minutes: 30, powerMode: .full, isPinned: false)
                Issue.record("Expected invalidPresetName for \"\(invalid)\"")
            } catch let error as CaffeinateServiceError {
                guard case .invalidPresetName = error else {
                    Issue.record("Expected .invalidPresetName, got \(error)")
                    continue
                }
            }
        }
    }

    @Test
    func corruptedPresetsJSONThrowsFailedToReadState() async throws {
        let harness = ServiceHarness()
        // Seed the directory + file by calling presets() once (writes defaults).
        _ = try await harness.service.presets()
        try harness.writeCorruptFile(named: "presets.json")

        do {
            _ = try await harness.service.presets()
            Issue.record("Expected failedToReadState")
        } catch let error as CaffeinateServiceError {
            guard case .failedToReadState = error else {
                Issue.record("Expected .failedToReadState, got \(error)")
                return
            }
        }
    }

    @Test
    func corruptedStateJSONThrowsFailedToReadState() async throws {
        let harness = ServiceHarness()
        // Ensure directory exists.
        _ = try await harness.service.presets()
        try harness.writeCorruptFile(named: "state.json")

        do {
            _ = try await harness.service.status()
            Issue.record("Expected failedToReadState")
        } catch let error as CaffeinateServiceError {
            guard case .failedToReadState = error else {
                Issue.record("Expected .failedToReadState, got \(error)")
                return
            }
        }
    }

    @Test
    func corruptedHistoryJSONThrowsFailedToReadState() async throws {
        let harness = ServiceHarness()
        _ = try await harness.service.presets()
        try harness.writeCorruptFile(named: "history.json")

        do {
            _ = try await harness.service.recentSessions(limit: 10)
            Issue.record("Expected failedToReadState")
        } catch let error as CaffeinateServiceError {
            guard case .failedToReadState = error else {
                Issue.record("Expected .failedToReadState, got \(error)")
                return
            }
        }
    }

    @Test
    func createPresetFailsOnUnwritableDirectory() async throws {
        let harness = ServiceHarness()
        // Seed so the directory exists.
        _ = try await harness.service.presets()

        let directory = harness.baseDirectory.appending(path: "SpotlightCaffeinate", directoryHint: .isDirectory)
        let originalAttributes = try FileManager.default.attributesOfItem(atPath: directory.path)
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: directory.path)
        defer {
            if let mode = originalAttributes[.posixPermissions] {
                try? FileManager.default.setAttributes([.posixPermissions: mode], ofItemAtPath: directory.path)
            } else {
                try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
            }
        }

        do {
            _ = try await harness.service.createPreset(name: "Blocked", minutes: 30, powerMode: .full, isPinned: false)
            Issue.record("Expected failedToPersist")
        } catch let error as CaffeinateServiceError {
            guard case .failedToPersist = error else {
                Issue.record("Expected .failedToPersist, got \(error)")
                return
            }
        }
    }

    @Test
    func separateServiceInstancesCanStopTheSameAssertionSession() async throws {
        let harness = ServiceHarness()
        harness.timeBox.now = Date(timeIntervalSinceReferenceDate: 1_000)
        _ = try await harness.service.start(minutes: 30, powerMode: .display, source: .app)

        let secondHarness = ServiceHarness(
            baseDirectory: harness.baseDirectory,
            processController: harness.processController,
            notificationCenter: harness.notificationCenter,
            timeBox: harness.timeBox
        )

        harness.timeBox.now = Date(timeIntervalSinceReferenceDate: 1_300)
        let status = try await secondHarness.service.status()
        let stopped = try await secondHarness.service.stop()

        #expect(status.state == .active)
        #expect(stopped.state == .inactive)
        #expect(harness.processController.terminatedAssertionGroups == [[100, 101]])
    }
}

private final class FakeProcessController: @unchecked Sendable, CaffeinateProcessControlling {
    var nextPID: Int32 = 100
    var launchedArguments: [[String]] = []
    var terminatedPIDs: [Int32] = []
    var terminatedAssertionGroups: [[UInt32]] = []
    var runningPIDs: Set<Int32> = []

    func launch(arguments: [String]) throws -> CaffeinateLaunchResult {
        launchedArguments.append(arguments)
        let pid = nextPID
        let flags = Set(arguments.filter { $0.hasPrefix("-") })
        let assertionCount =
            (flags.contains("-d") ? 1 : 0) +
            ((flags.contains("-i") || flags.contains("-s")) ? 1 : 0) +
            (flags.contains("-u") ? 1 : 0)
        let assertionIDs = (0..<assertionCount).map { UInt32(pid + Int32($0)) }
        nextPID += Int32(max(assertionCount, 1))
        runningPIDs.insert(pid)
        return CaffeinateLaunchResult(pid: pid, assertionIDs: assertionIDs)
    }

    func terminate(pid: Int32) throws {
        terminatedPIDs.append(pid)
        runningPIDs.remove(pid)
    }

    func terminate(assertionIDs: [UInt32]) throws {
        terminatedAssertionGroups.append(assertionIDs)
        runningPIDs.remove(Int32(assertionIDs.first ?? 0))
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
        self.init(
            baseDirectory: FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory),
            processController: FakeProcessController(),
            notificationCenter: FakeNotificationCenter(),
            timeBox: TimeBox(),
            sessionBackend: .assertion
        )
    }

    init(sessionBackend: CaffeinateSessionBackend) {
        self.init(
            baseDirectory: FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory),
            processController: FakeProcessController(),
            notificationCenter: FakeNotificationCenter(),
            timeBox: TimeBox(),
            sessionBackend: sessionBackend
        )
    }

    init(
        baseDirectory: URL,
        processController: FakeProcessController,
        notificationCenter: FakeNotificationCenter,
        timeBox: TimeBox,
        sessionBackend: CaffeinateSessionBackend = .assertion
    ) {
        self.baseDirectory = baseDirectory
        self.processController = processController
        self.notificationCenter = notificationCenter
        self.timeBox = timeBox
        service = CaffeinateService(
            baseDirectory: baseDirectory,
            notificationService: notificationCenter,
            processController: processController,
            sessionBackend: sessionBackend,
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

    func writeCorruptFile(named fileName: String) throws {
        let directory = baseDirectory.appending(path: "SpotlightCaffeinate", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("{not-json".utf8).write(to: directory.appending(path: fileName), options: .atomic)
    }
}
