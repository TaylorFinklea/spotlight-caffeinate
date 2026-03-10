import Darwin
import Foundation

enum CaffeinateServiceError: LocalizedError {
    case invalidMinutes
    case failedToLaunch(String)
    case failedToPersist(String)
    case failedToReadState(String)
    case failedToStop(String)

    var errorDescription: String? {
        switch self {
        case .invalidMinutes:
            return "Choose a duration between 1 and 1440 minutes."
        case .failedToLaunch(let reason):
            return "Unable to launch caffeinate: \(reason)"
        case .failedToPersist(let reason):
            return "Unable to save app state: \(reason)"
        case .failedToReadState(let reason):
            return "Unable to read app state: \(reason)"
        case .failedToStop(let reason):
            return "Unable to stop caffeinate: \(reason)"
        }
    }
}

private struct CaffeinateRecord: Codable, Sendable {
    let pid: Int32
    let startedAt: Date
    let endsAt: Date
    let minutes: Int
}

actor CaffeinateService {
    static let shared = CaffeinateService()

    private let stateURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let notificationService: CaffeinateNotificationService

    init(notificationService: CaffeinateNotificationService = .shared) {
        self.notificationService = notificationService

        let baseDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appending(path: "Library/Application Support", directoryHint: .isDirectory)

        let appDirectory = baseDirectory.appending(path: "SpotlightCaffeinate", directoryHint: .isDirectory)
        stateURL = appDirectory.appending(path: "state.json")

        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func start(minutes: Int) async throws -> CaffeinateSnapshot {
        guard (1...1440).contains(minutes) else {
            throw CaffeinateServiceError.invalidMinutes
        }

        _ = try await stop()

        let seconds = minutes * 60
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
        process.arguments = ["-t", String(seconds)]

        do {
            try process.run()
        } catch {
            throw CaffeinateServiceError.failedToLaunch(error.localizedDescription)
        }

        let now = Date()
        let record = CaffeinateRecord(
            pid: process.processIdentifier,
            startedAt: now,
            endsAt: now.addingTimeInterval(TimeInterval(seconds)),
            minutes: minutes
        )

        try persist(record)

        let snapshot = snapshot(from: record)
        await notificationService.scheduleCompletionNotificationIfNeeded(for: snapshot)
        return snapshot
    }

    func stop() async throws -> CaffeinateSnapshot {
        guard let record = try loadRecord() else {
            await notificationService.cancelPendingCompletionNotification()
            return .inactive
        }

        if isProcessRunning(record.pid), kill(record.pid, SIGTERM) != 0, errno != ESRCH {
            let reason = String(cString: strerror(errno))
            throw CaffeinateServiceError.failedToStop(reason)
        }

        try clearRecord()
        await notificationService.cancelPendingCompletionNotification()
        return .inactive
    }

    func status() async throws -> CaffeinateSnapshot {
        guard let record = try loadRecord() else {
            await notificationService.cancelPendingCompletionNotification()
            return .inactive
        }

        guard isProcessRunning(record.pid), record.endsAt > Date() else {
            try clearRecord()
            await notificationService.cancelPendingCompletionNotification()
            return .inactive
        }

        return snapshot(from: record)
    }

    private func snapshot(from record: CaffeinateRecord) -> CaffeinateSnapshot {
        CaffeinateSnapshot(
            state: .active,
            pid: record.pid,
            startedAt: record.startedAt,
            endsAt: record.endsAt,
            minutesRequested: record.minutes
        )
    }

    private func persist(_ record: CaffeinateRecord) throws {
        let directory = stateURL.deletingLastPathComponent()

        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try encoder.encode(record)
            try data.write(to: stateURL, options: .atomic)
        } catch {
            throw CaffeinateServiceError.failedToPersist(error.localizedDescription)
        }
    }

    private func loadRecord() throws -> CaffeinateRecord? {
        guard FileManager.default.fileExists(atPath: stateURL.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: stateURL)
            return try decoder.decode(CaffeinateRecord.self, from: data)
        } catch {
            throw CaffeinateServiceError.failedToReadState(error.localizedDescription)
        }
    }

    private func clearRecord() throws {
        guard FileManager.default.fileExists(atPath: stateURL.path) else {
            return
        }

        do {
            try FileManager.default.removeItem(at: stateURL)
        } catch {
            throw CaffeinateServiceError.failedToPersist(error.localizedDescription)
        }
    }

    private func isProcessRunning(_ pid: Int32) -> Bool {
        kill(pid, 0) == 0 || errno == EPERM
    }
}
