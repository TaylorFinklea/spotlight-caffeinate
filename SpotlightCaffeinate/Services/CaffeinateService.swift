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
    let processStartIdentifier: String?
}

actor CaffeinateService {
    static let shared = CaffeinateService()

    private let stateURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        let baseDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appending(path: "Library/Application Support", directoryHint: .isDirectory)

        let appDirectory = baseDirectory.appending(path: "SpotlightCaffeinate", directoryHint: .isDirectory)
        stateURL = appDirectory.appending(path: "state.json")

        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func start(minutes: Int) throws -> CaffeinateSnapshot {
        guard (1...1440).contains(minutes) else {
            throw CaffeinateServiceError.invalidMinutes
        }

        _ = try stop()

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
            minutes: minutes,
            processStartIdentifier: processStartIdentifier(for: process.processIdentifier)
        )

        try persist(record)
        return snapshot(from: record)
    }

    func stop() throws -> CaffeinateSnapshot {
        guard let record = try loadRecord() else {
            return .inactive
        }

        if matchesTrackedProcess(record), kill(record.pid, SIGTERM) != 0, errno != ESRCH {
            let reason = String(cString: strerror(errno))
            throw CaffeinateServiceError.failedToStop(reason)
        }

        try clearRecord()
        return .inactive
    }

    func status() throws -> CaffeinateSnapshot {
        guard let record = try loadRecord() else {
            return .inactive
        }

        guard matchesTrackedProcess(record), record.endsAt > Date() else {
            try clearRecord()
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
        guard FileManager.default.fileExists(atPath: stateURL.path()) else {
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
        guard FileManager.default.fileExists(atPath: stateURL.path()) else {
            return
        }

        do {
            try FileManager.default.removeItem(at: stateURL)
        } catch {
            throw CaffeinateServiceError.failedToPersist(error.localizedDescription)
        }
    }

    private func matchesTrackedProcess(_ record: CaffeinateRecord) -> Bool {
        guard kill(record.pid, 0) == 0 || errno == EPERM else {
            return false
        }

        guard let expectedProcessStartIdentifier = record.processStartIdentifier else {
            return true
        }

        return processStartIdentifier(for: record.pid) == expectedProcessStartIdentifier
    }

    private func processStartIdentifier(for pid: Int32) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-p", String(pid), "-o", "lstart="]

        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return nil
        }

        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            return nil
        }

        let data = output.fileHandleForReading.readDataToEndOfFile()
        let value = String(decoding: data, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return value.isEmpty ? nil : value
    }
}
