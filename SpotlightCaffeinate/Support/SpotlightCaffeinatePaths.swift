import Foundation

struct SpotlightCaffeinateStorageContext: Sendable {
    let directory: URL
    let usesSharedContainer: Bool
    let shouldWarnStandaloneCLIAboutUnsyncedApp: Bool
}

struct SpotlightCaffeinateStorageEnvironment: Sendable {
    let appGroupContainerDirectory: URL?
    let userApplicationSupportDirectory: URL
    let sandboxApplicationSupportDirectory: URL?
}

enum SpotlightCaffeinatePaths {
    static let appDirectoryName = "SpotlightCaffeinate"
    static let bundleIdentifier = "io.taylorfinklea.spotlightcaffeinate"
    static let appGroupIdentifier = "group.io.taylorfinklea.spotlightcaffeinate"

    private static let stateFileName = "state.json"
    private static let presetsFileName = "presets.json"
    private static let historyFileName = "history.json"
    private static let automationsFileName = "automations.json"
    private static let automationHistoryFileName = "automation-history.json"
    private static let managedFileNames = [
        stateFileName,
        presetsFileName,
        historyFileName,
        automationsFileName,
        automationHistoryFileName,
    ]

    static func applicationSupportDirectory(fileManager: FileManager = .default) -> URL {
        storageContext(fileManager: fileManager).directory
    }

    static func storageContext(fileManager: FileManager = .default) -> SpotlightCaffeinateStorageContext {
        let environment = defaultEnvironment(fileManager: fileManager)

        do {
            return try prepareStorage(fileManager: fileManager, environment: environment)
        } catch {
            return fallbackStorageContext(fileManager: fileManager, environment: environment)
        }
    }

    static func prepareStorage(
        fileManager: FileManager = .default,
        environment: SpotlightCaffeinateStorageEnvironment
    ) throws -> SpotlightCaffeinateStorageContext {
        if let appGroupContainerDirectory = environment.appGroupContainerDirectory {
            let sharedDirectory = appGroupContainerDirectory.appending(path: appDirectoryName, directoryHint: .isDirectory)
            try fileManager.createDirectory(at: sharedDirectory, withIntermediateDirectories: true)
            try migrateLegacyStoresIfNeeded(
                to: sharedDirectory,
                fileManager: fileManager,
                environment: environment
            )

            return SpotlightCaffeinateStorageContext(
                directory: sharedDirectory,
                usesSharedContainer: true,
                shouldWarnStandaloneCLIAboutUnsyncedApp: false
            )
        }

        let legacyDirectory = environment.userApplicationSupportDirectory.appending(path: appDirectoryName, directoryHint: .isDirectory)
        try fileManager.createDirectory(at: legacyDirectory, withIntermediateDirectories: true)

        return SpotlightCaffeinateStorageContext(
            directory: legacyDirectory,
            usesSharedContainer: false,
            shouldWarnStandaloneCLIAboutUnsyncedApp: sandboxLegacyDirectoryExists(
                fileManager: fileManager,
                environment: environment
            )
        )
    }

    private static func fallbackStorageContext(
        fileManager: FileManager,
        environment: SpotlightCaffeinateStorageEnvironment
    ) -> SpotlightCaffeinateStorageContext {
        let legacyDirectory = environment.userApplicationSupportDirectory.appending(path: appDirectoryName, directoryHint: .isDirectory)
        try? fileManager.createDirectory(at: legacyDirectory, withIntermediateDirectories: true)

        return SpotlightCaffeinateStorageContext(
            directory: legacyDirectory,
            usesSharedContainer: false,
            shouldWarnStandaloneCLIAboutUnsyncedApp: sandboxLegacyDirectoryExists(
                fileManager: fileManager,
                environment: environment
            )
        )
    }

    private static func defaultEnvironment(fileManager: FileManager) -> SpotlightCaffeinateStorageEnvironment {
        let userApplicationSupportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appending(path: "Library/Application Support", directoryHint: .isDirectory)

        return SpotlightCaffeinateStorageEnvironment(
            appGroupContainerDirectory: fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier),
            userApplicationSupportDirectory: userApplicationSupportDirectory,
            // Avoid probing ~/Library/Containers directly on launch, which can trigger
            // macOS app-data access prompts. When the current process is already sandboxed,
            // its application support directory already points at the legacy container.
            sandboxApplicationSupportDirectory: inferredSandboxApplicationSupportDirectory(
                from: userApplicationSupportDirectory
            )
        )
    }

    private static func inferredSandboxApplicationSupportDirectory(from directory: URL) -> URL? {
        let normalizedPath = directory.standardizedFileURL.path
        let sandboxSuffix = "/Library/Containers/\(bundleIdentifier)/Data/Library/Application Support"
        return normalizedPath.contains(sandboxSuffix) ? directory : nil
    }

    private static func migrateLegacyStoresIfNeeded(
        to sharedDirectory: URL,
        fileManager: FileManager,
        environment: SpotlightCaffeinateStorageEnvironment
    ) throws {
        guard !containsManagedFiles(at: sharedDirectory, fileManager: fileManager) else {
            return
        }

        let standaloneDirectory = environment.userApplicationSupportDirectory.appending(path: appDirectoryName, directoryHint: .isDirectory)
        let sandboxDirectory = environment.sandboxApplicationSupportDirectory?.appending(path: appDirectoryName, directoryHint: .isDirectory)

        try migratePreferredFile(
            named: presetsFileName,
            to: sharedDirectory,
            preferredDirectory: sandboxDirectory,
            fallbackDirectory: standaloneDirectory,
            fileManager: fileManager
        )
        try migratePreferredFile(
            named: automationsFileName,
            to: sharedDirectory,
            preferredDirectory: sandboxDirectory,
            fallbackDirectory: standaloneDirectory,
            fileManager: fileManager
        )
        try migrateSessionState(
            to: sharedDirectory,
            preferredDirectory: sandboxDirectory,
            fallbackDirectory: standaloneDirectory,
            fileManager: fileManager
        )
        try migrateRecentSessionHistory(
            to: sharedDirectory,
            preferredDirectory: sandboxDirectory,
            fallbackDirectory: standaloneDirectory,
            fileManager: fileManager
        )
        try migrateAutomationHistory(
            to: sharedDirectory,
            preferredDirectory: sandboxDirectory,
            fallbackDirectory: standaloneDirectory,
            fileManager: fileManager
        )
    }

    private static func migratePreferredFile(
        named fileName: String,
        to sharedDirectory: URL,
        preferredDirectory: URL?,
        fallbackDirectory: URL,
        fileManager: FileManager
    ) throws {
        let targetURL = sharedDirectory.appending(path: fileName)
        guard !fileManager.fileExists(atPath: targetURL.path) else {
            return
        }

        for sourceDirectory in [preferredDirectory, fallbackDirectory] {
            guard let sourceDirectory else {
                continue
            }

            let sourceURL = sourceDirectory.appending(path: fileName)
            guard fileManager.fileExists(atPath: sourceURL.path) else {
                continue
            }

            let data = try Data(contentsOf: sourceURL)
            try data.write(to: targetURL, options: .atomic)
            return
        }
    }

    private static func migrateSessionState(
        to sharedDirectory: URL,
        preferredDirectory: URL?,
        fallbackDirectory: URL,
        fileManager: FileManager
    ) throws {
        let targetURL = sharedDirectory.appending(path: stateFileName)
        guard !fileManager.fileExists(atPath: targetURL.path) else {
            return
        }

        let candidateURLs = [
            preferredDirectory?.appending(path: stateFileName),
            fallbackDirectory.appending(path: stateFileName),
        ]

        for candidateURL in candidateURLs {
            guard
                let candidateURL,
                let record = try loadJSON(CaffeinateRecord.self, from: candidateURL),
                record.endsAt > .now
            else {
                continue
            }

            try writeJSON(record, to: targetURL)
            return
        }
    }

    private static func migrateRecentSessionHistory(
        to sharedDirectory: URL,
        preferredDirectory: URL?,
        fallbackDirectory: URL,
        fileManager: FileManager
    ) throws {
        let targetURL = sharedDirectory.appending(path: historyFileName)
        guard !fileManager.fileExists(atPath: targetURL.path) else {
            return
        }

        let preferredHistory = try loadJSON([RecentSessionEntry].self, from: preferredDirectory?.appending(path: historyFileName)) ?? []
        let fallbackHistory = try loadJSON([RecentSessionEntry].self, from: fallbackDirectory.appending(path: historyFileName)) ?? []
        let mergedHistory = deduplicatedRecentSessions(preferredHistory + fallbackHistory)

        guard !mergedHistory.isEmpty else {
            return
        }

        try writeJSON(mergedHistory, to: targetURL)
    }

    private static func migrateAutomationHistory(
        to sharedDirectory: URL,
        preferredDirectory: URL?,
        fallbackDirectory: URL,
        fileManager: FileManager
    ) throws {
        let targetURL = sharedDirectory.appending(path: automationHistoryFileName)
        guard !fileManager.fileExists(atPath: targetURL.path) else {
            return
        }

        let preferredHistory = try loadJSON([AutomationRunRecord].self, from: preferredDirectory?.appending(path: automationHistoryFileName)) ?? []
        let fallbackHistory = try loadJSON([AutomationRunRecord].self, from: fallbackDirectory.appending(path: automationHistoryFileName)) ?? []
        let mergedHistory = deduplicatedAutomationHistory(preferredHistory + fallbackHistory)

        guard !mergedHistory.isEmpty else {
            return
        }

        try writeJSON(mergedHistory, to: targetURL)
    }

    private static func containsManagedFiles(at directory: URL, fileManager: FileManager) -> Bool {
        managedFileNames.contains { fileManager.fileExists(atPath: directory.appending(path: $0).path) }
    }

    private static func sandboxLegacyDirectoryExists(
        fileManager: FileManager,
        environment: SpotlightCaffeinateStorageEnvironment
    ) -> Bool {
        guard let sandboxApplicationSupportDirectory = environment.sandboxApplicationSupportDirectory else {
            return false
        }

        let directory = sandboxApplicationSupportDirectory.appending(path: appDirectoryName, directoryHint: .isDirectory)
        return fileManager.fileExists(atPath: directory.path)
    }

    private static func loadJSON<T: Decodable>(_ type: T.Type, from url: URL?) throws -> T? {
        guard let url else {
            return nil
        }

        let data = try? Data(contentsOf: url)
        guard let data else {
            return nil
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: data)
    }

    private static func writeJSON<T: Encodable>(_ value: T, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(value)
        try data.write(to: url, options: .atomic)
    }

    private static func deduplicatedRecentSessions(_ entries: [RecentSessionEntry]) -> [RecentSessionEntry] {
        var seen = Set<String>()

        return entries
            .sorted { lhs, rhs in
                if lhs.endedAt == rhs.endedAt {
                    return lhs.startedAt > rhs.startedAt
                }
                return lhs.endedAt > rhs.endedAt
            }
            .filter { entry in
                seen.insert(recentSessionSignature(for: entry)).inserted
            }
    }

    private static func deduplicatedAutomationHistory(_ entries: [AutomationRunRecord]) -> [AutomationRunRecord] {
        var seen = Set<String>()

        return entries
            .sorted { lhs, rhs in
                if lhs.firedAt == rhs.firedAt {
                    return lhs.ruleName < rhs.ruleName
                }
                return lhs.firedAt > rhs.firedAt
            }
            .filter { entry in
                seen.insert(automationHistorySignature(for: entry)).inserted
            }
    }

    private static func recentSessionSignature(for entry: RecentSessionEntry) -> String {
        [
            entry.startedAt.ISO8601Format(),
            entry.endedAt.ISO8601Format(),
            String(entry.minutesRequested),
            entry.powerMode.rawValue,
            entry.presetName ?? "",
            entry.source.rawValue,
            entry.automationRuleName ?? "",
        ].joined(separator: "|")
    }

    private static func automationHistorySignature(for entry: AutomationRunRecord) -> String {
        [
            entry.ruleName,
            entry.firedAt.ISO8601Format(),
            entry.outcome.rawValue,
            entry.message,
            entry.calendarEventID ?? "",
        ].joined(separator: "|")
    }
}
