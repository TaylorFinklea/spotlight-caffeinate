import Foundation

enum CaffeinateServiceError: LocalizedError {
    case invalidMinutes
    case invalidPresetName
    case failedToLaunch(String)
    case failedToPersist(String)
    case failedToReadState(String)
    case failedToStop(String)
    case noActiveSession
    case noRecentSession
    case presetNotFound(String)

    var errorDescription: String? {
        switch self {
        case .invalidMinutes:
            return "Choose a duration between 1 and 1440 minutes."
        case .invalidPresetName:
            return "Preset names cannot be empty."
        case .failedToLaunch(let reason):
            return "Unable to launch caffeinate: \(reason)"
        case .failedToPersist(let reason):
            return "Unable to save app state: \(reason)"
        case .failedToReadState(let reason):
            return "Unable to read app state: \(reason)"
        case .failedToStop(let reason):
            return "Unable to stop caffeinate: \(reason)"
        case .noActiveSession:
            return "Caffeinate is not running."
        case .noRecentSession:
            return "No recent session is available to restart."
        case .presetNotFound(let name):
            return "Could not find a preset named '\(name)'."
        }
    }
}

private struct CaffeinateRecord: Codable, Sendable {
    let pid: Int32
    let startedAt: Date
    let endsAt: Date
    let minutes: Int
    let powerMode: PowerMode?
    let presetID: UUID?
    let presetName: String?
    let source: CaffeinateSessionSource?
}

protocol CaffeinateNotificationScheduling: Sendable {
    func scheduleCompletionNotificationIfNeeded(for snapshot: CaffeinateSnapshot) async
    func cancelPendingCompletionNotification() async
}

actor CaffeinateService {
    static let shared = CaffeinateService()

    private let stateURL: URL
    private let presetsURL: URL
    private let historyURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let notificationService: any CaffeinateNotificationScheduling
    private let processController: any CaffeinateProcessControlling
    private let now: @Sendable () -> Date

    private static let historyLimit = 20

    init(notificationService: CaffeinateNotificationService = .shared) {
        let baseDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appending(path: "Library/Application Support", directoryHint: .isDirectory)
        self.notificationService = notificationService
        processController = SystemCaffeinateProcessController()
        now = Date.init

        let appDirectory = baseDirectory.appending(path: "SpotlightCaffeinate", directoryHint: .isDirectory)
        stateURL = appDirectory.appending(path: "state.json")
        presetsURL = appDirectory.appending(path: "presets.json")
        historyURL = appDirectory.appending(path: "history.json")

        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    init(
        baseDirectory: URL,
        notificationService: any CaffeinateNotificationScheduling,
        processController: any CaffeinateProcessControlling,
        now: @escaping @Sendable () -> Date
    ) {
        self.notificationService = notificationService
        self.processController = processController
        self.now = now

        let appDirectory = baseDirectory.appending(path: "SpotlightCaffeinate", directoryHint: .isDirectory)
        stateURL = appDirectory.appending(path: "state.json")
        presetsURL = appDirectory.appending(path: "presets.json")
        historyURL = appDirectory.appending(path: "history.json")

        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func start(
        minutes: Int,
        powerMode: PowerMode = .full,
        presetID: UUID? = nil,
        presetName: String? = nil,
        source: CaffeinateSessionSource = .app
    ) async throws -> CaffeinateSnapshot {
        try validate(minutes: minutes)

        let currentDate = now()
        try await archiveAndClearCurrentSession(endedAt: currentDate)

        let endsAt = currentDate.addingTimeInterval(TimeInterval(minutes * 60))
        return try await beginSession(
            launchedAt: currentDate,
            startedAt: currentDate,
            endsAt: endsAt,
            minutesRequested: minutes,
            powerMode: powerMode,
            presetID: presetID,
            presetName: presetName,
            source: source
        )
    }

    func stop() async throws -> CaffeinateSnapshot {
        guard let record = try loadRecord() else {
            await notificationService.cancelPendingCompletionNotification()
            return .inactive
        }

        do {
            try processController.terminate(pid: record.pid)
        } catch {
            throw CaffeinateServiceError.failedToStop(error.localizedDescription)
        }

        try appendToHistory(record, endedAt: now())
        try clearRecord()
        await notificationService.cancelPendingCompletionNotification()
        return .inactive
    }

    func status() async throws -> CaffeinateSnapshot {
        guard let record = try loadRecord() else {
            await notificationService.cancelPendingCompletionNotification()
            return .inactive
        }

        let currentDate = now()

        guard processController.isRunning(pid: record.pid), record.endsAt > currentDate else {
            try appendToHistory(record, endedAt: min(currentDate, record.endsAt))
            try clearRecord()
            await notificationService.cancelPendingCompletionNotification()
            return .inactive
        }

        return snapshot(from: record)
    }

    func extend(
        minutes: Int,
        powerMode: PowerMode? = nil,
        presetID: UUID? = nil,
        presetName: String? = nil,
        source: CaffeinateSessionSource = .app
    ) async throws -> CaffeinateSnapshot {
        try validate(minutes: minutes)

        let currentDate = now()
        let record = try await activeRecord(now: currentDate)
        let selectedPowerMode = powerMode ?? record.powerMode ?? .full
        let updatedEndsAt = record.endsAt.addingTimeInterval(TimeInterval(minutes * 60))
        let updatedMinutes = record.minutes + minutes

        do {
            try processController.terminate(pid: record.pid)
        } catch {
            throw CaffeinateServiceError.failedToStop(error.localizedDescription)
        }

        return try await beginSession(
            launchedAt: currentDate,
            startedAt: record.startedAt,
            endsAt: updatedEndsAt,
            minutesRequested: updatedMinutes,
            powerMode: selectedPowerMode,
            presetID: presetID ?? record.presetID,
            presetName: presetName ?? record.presetName,
            source: source
        )
    }

    func restartLast(source: CaffeinateSessionSource = .app) async throws -> CaffeinateSnapshot {
        guard let entry = try recentSessions(limit: 1).first else {
            throw CaffeinateServiceError.noRecentSession
        }

        return try await start(
            minutes: entry.minutesRequested,
            powerMode: entry.powerMode,
            presetID: entry.presetID,
            presetName: entry.presetName,
            source: source
        )
    }

    func startPreset(id: UUID, source: CaffeinateSessionSource = .app) async throws -> CaffeinateSnapshot {
        guard let preset = try presets().first(where: { $0.id == id }) else {
            throw CaffeinateServiceError.presetNotFound(id.uuidString)
        }

        return try await start(preset: preset, source: source)
    }

    func startPreset(named name: String, source: CaffeinateSessionSource = .app) async throws -> CaffeinateSnapshot {
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let preset = try presets().first(where: { $0.name.caseInsensitiveCompare(normalized) == .orderedSame }) else {
            throw CaffeinateServiceError.presetNotFound(normalized)
        }

        return try await start(preset: preset, source: source)
    }

    func extendPreset(id: UUID, source: CaffeinateSessionSource = .app) async throws -> CaffeinateSnapshot {
        guard let preset = try presets().first(where: { $0.id == id }) else {
            throw CaffeinateServiceError.presetNotFound(id.uuidString)
        }

        return try await extend(
            minutes: preset.minutes,
            powerMode: preset.powerMode,
            presetID: preset.id,
            presetName: preset.name,
            source: source
        )
    }

    func extendPreset(named name: String, source: CaffeinateSessionSource = .app) async throws -> CaffeinateSnapshot {
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let preset = try presets().first(where: { $0.name.caseInsensitiveCompare(normalized) == .orderedSame }) else {
            throw CaffeinateServiceError.presetNotFound(normalized)
        }

        return try await extend(
            minutes: preset.minutes,
            powerMode: preset.powerMode,
            presetID: preset.id,
            presetName: preset.name,
            source: source
        )
    }

    func presets() throws -> [CaffeinatePreset] {
        try loadPresets()
    }

    func recentSessions(limit: Int = historyLimit) throws -> [RecentSessionEntry] {
        Array(try loadHistory().prefix(max(0, limit)))
    }

    func createPreset(
        name: String,
        minutes: Int,
        powerMode: PowerMode,
        isPinned: Bool
    ) throws -> [CaffeinatePreset] {
        try validate(minutes: minutes)
        let normalizedName = try validate(presetName: name)
        let currentDate = now()
        var existing = try loadPresets()
        existing.append(
            CaffeinatePreset(
                id: UUID(),
                name: normalizedName,
                minutes: minutes,
                powerMode: powerMode,
                isPinned: isPinned,
                sortOrder: existing.count,
                createdAt: currentDate,
                updatedAt: currentDate
            )
        )

        return try persistPresets(existing)
    }

    func updatePreset(
        id: UUID,
        name: String,
        minutes: Int,
        powerMode: PowerMode,
        isPinned: Bool
    ) throws -> [CaffeinatePreset] {
        try validate(minutes: minutes)
        let normalizedName = try validate(presetName: name)
        let currentDate = now()
        var existing = try loadPresets()
        guard let index = existing.firstIndex(where: { $0.id == id }) else {
            throw CaffeinateServiceError.presetNotFound(id.uuidString)
        }

        existing[index].name = normalizedName
        existing[index].minutes = minutes
        existing[index].powerMode = powerMode
        existing[index].isPinned = isPinned
        existing[index].updatedAt = currentDate
        return try persistPresets(existing)
    }

    func deletePreset(id: UUID) throws -> [CaffeinatePreset] {
        var existing = try loadPresets()
        existing.removeAll { $0.id == id }
        return try persistPresets(existing)
    }

    func movePreset(id: UUID, direction: PresetMoveDirection) throws -> [CaffeinatePreset] {
        var existing = try loadPresets()
        guard let index = existing.firstIndex(where: { $0.id == id }) else {
            throw CaffeinateServiceError.presetNotFound(id.uuidString)
        }

        let targetIndex: Int
        switch direction {
        case .up:
            targetIndex = max(0, index - 1)
        case .down:
            targetIndex = min(existing.count - 1, index + 1)
        }

        guard targetIndex != index else {
            return existing
        }

        let preset = existing.remove(at: index)
        existing.insert(preset, at: targetIndex)
        return try persistPresets(existing)
    }

    private func snapshot(from record: CaffeinateRecord) -> CaffeinateSnapshot {
        CaffeinateSnapshot(
            state: .active,
            pid: record.pid,
            startedAt: record.startedAt,
            endsAt: record.endsAt,
            minutesRequested: record.minutes,
            powerMode: record.powerMode ?? .full,
            presetID: record.presetID,
            presetName: record.presetName,
            source: record.source
        )
    }

    private func persist(_ record: CaffeinateRecord) throws {
        do {
            try FileManager.default.createDirectory(at: stateURL.deletingLastPathComponent(), withIntermediateDirectories: true)
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

    private func beginSession(
        launchedAt: Date,
        startedAt: Date,
        endsAt: Date,
        minutesRequested: Int,
        powerMode: PowerMode,
        presetID: UUID?,
        presetName: String?,
        source: CaffeinateSessionSource
    ) async throws -> CaffeinateSnapshot {
        let remainingSeconds = max(1, Int(endsAt.timeIntervalSince(launchedAt).rounded(.down)))
        let arguments = Self.arguments(for: powerMode, seconds: remainingSeconds)

        let pid: Int32
        do {
            pid = try processController.launch(arguments: arguments)
        } catch {
            throw CaffeinateServiceError.failedToLaunch(error.localizedDescription)
        }

        let record = CaffeinateRecord(
            pid: pid,
            startedAt: startedAt,
            endsAt: endsAt,
            minutes: minutesRequested,
            powerMode: powerMode,
            presetID: presetID,
            presetName: presetName,
            source: source
        )

        try persist(record)
        let snapshot = snapshot(from: record)
        await notificationService.scheduleCompletionNotificationIfNeeded(for: snapshot)
        return snapshot
    }

    private func activeRecord(now: Date) async throws -> CaffeinateRecord {
        guard let record = try loadRecord() else {
            throw CaffeinateServiceError.noActiveSession
        }

        guard processController.isRunning(pid: record.pid), record.endsAt > now else {
            try appendToHistory(record, endedAt: min(now, record.endsAt))
            try clearRecord()
            await notificationService.cancelPendingCompletionNotification()
            throw CaffeinateServiceError.noActiveSession
        }

        return record
    }

    private func archiveAndClearCurrentSession(endedAt: Date) async throws {
        guard let record = try loadRecord() else {
            await notificationService.cancelPendingCompletionNotification()
            return
        }

        do {
            try processController.terminate(pid: record.pid)
        } catch {
            throw CaffeinateServiceError.failedToStop(error.localizedDescription)
        }

        try appendToHistory(record, endedAt: endedAt)
        try clearRecord()
        await notificationService.cancelPendingCompletionNotification()
    }

    private func appendToHistory(_ record: CaffeinateRecord, endedAt: Date) throws {
        var history = try loadHistory()
        let entry = RecentSessionEntry(
            id: UUID(),
            startedAt: record.startedAt,
            endedAt: max(record.startedAt, endedAt),
            minutesRequested: record.minutes,
            powerMode: record.powerMode ?? .full,
            presetID: record.presetID,
            presetName: record.presetName,
            source: record.source ?? .app
        )

        history.insert(entry, at: 0)
        if history.count > Self.historyLimit {
            history = Array(history.prefix(Self.historyLimit))
        }

        try persistHistory(history)
    }

    private func loadPresets() throws -> [CaffeinatePreset] {
        guard FileManager.default.fileExists(atPath: presetsURL.path) else {
            let defaults = CaffeinatePreset.defaultPresets(referenceDate: now())
            return try persistPresets(defaults)
        }

        do {
            let data = try Data(contentsOf: presetsURL)
            let decoded = try decoder.decode([CaffeinatePreset].self, from: data)
            return normalizePresets(decoded)
        } catch {
            throw CaffeinateServiceError.failedToReadState(error.localizedDescription)
        }
    }

    private func persistPresets(_ presets: [CaffeinatePreset]) throws -> [CaffeinatePreset] {
        let normalized = normalizePresets(presets)

        do {
            try FileManager.default.createDirectory(at: presetsURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try encoder.encode(normalized)
            try data.write(to: presetsURL, options: .atomic)
            return normalized
        } catch {
            throw CaffeinateServiceError.failedToPersist(error.localizedDescription)
        }
    }

    private func loadHistory() throws -> [RecentSessionEntry] {
        guard FileManager.default.fileExists(atPath: historyURL.path) else {
            return []
        }

        do {
            let data = try Data(contentsOf: historyURL)
            return try decoder.decode([RecentSessionEntry].self, from: data)
        } catch {
            throw CaffeinateServiceError.failedToReadState(error.localizedDescription)
        }
    }

    private func persistHistory(_ history: [RecentSessionEntry]) throws {
        do {
            try FileManager.default.createDirectory(at: historyURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try encoder.encode(Array(history.prefix(Self.historyLimit)))
            try data.write(to: historyURL, options: .atomic)
        } catch {
            throw CaffeinateServiceError.failedToPersist(error.localizedDescription)
        }
    }

    private func validate(minutes: Int) throws {
        guard (1...1440).contains(minutes) else {
            throw CaffeinateServiceError.invalidMinutes
        }
    }

    private func validate(presetName: String) throws -> String {
        let normalized = presetName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            throw CaffeinateServiceError.invalidPresetName
        }

        return normalized
    }

    private func normalizePresets(_ presets: [CaffeinatePreset]) -> [CaffeinatePreset] {
        presets
            .sorted { lhs, rhs in
                if lhs.sortOrder == rhs.sortOrder {
                    return lhs.createdAt < rhs.createdAt
                }

                return lhs.sortOrder < rhs.sortOrder
            }
            .enumerated()
            .map { index, preset in
                var preset = preset
                preset.sortOrder = index
                return preset
            }
    }

    private func start(preset: CaffeinatePreset, source: CaffeinateSessionSource) async throws -> CaffeinateSnapshot {
        try await start(
            minutes: preset.minutes,
            powerMode: preset.powerMode,
            presetID: preset.id,
            presetName: preset.name,
            source: source
        )
    }

    static func arguments(for powerMode: PowerMode, seconds: Int) -> [String] {
        powerMode.caffeinateFlags + ["-t", String(seconds)]
    }
}

enum PresetMoveDirection {
    case up
    case down
}
