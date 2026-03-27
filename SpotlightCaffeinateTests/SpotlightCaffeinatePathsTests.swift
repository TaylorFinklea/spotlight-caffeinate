import Foundation
import Testing

struct SpotlightCaffeinatePathsTests {
    @Test
    func sharedContainerMigrationPrefersAppDataAndCarriesActiveCLIState() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let sharedGroupRoot = root.appending(path: "AppGroup", directoryHint: .isDirectory)
        let userApplicationSupportDirectory = root.appending(path: "Application Support", directoryHint: .isDirectory)
        let sandboxApplicationSupportDirectory = root
            .appending(path: "Containers/io.taylorfinklea.spotlightcaffeinate/Data/Library/Application Support", directoryHint: .isDirectory)

        let standaloneDirectory = userApplicationSupportDirectory.appending(path: SpotlightCaffeinatePaths.appDirectoryName, directoryHint: .isDirectory)
        let sandboxDirectory = sandboxApplicationSupportDirectory.appending(path: SpotlightCaffeinatePaths.appDirectoryName, directoryHint: .isDirectory)

        try fileManager.createDirectory(at: standaloneDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: sandboxDirectory, withIntermediateDirectories: true)

        let appPreset = CaffeinatePreset(
            id: UUID(),
            name: "App 60m",
            minutes: 60,
            powerMode: .full,
            isPinned: true,
            sortOrder: 0,
            createdAt: Date(timeIntervalSinceReferenceDate: 10),
            updatedAt: Date(timeIntervalSinceReferenceDate: 10)
        )
        let cliPreset = CaffeinatePreset(
            id: UUID(),
            name: "CLI 45m",
            minutes: 45,
            powerMode: .system,
            isPinned: false,
            sortOrder: 0,
            createdAt: Date(timeIntervalSinceReferenceDate: 20),
            updatedAt: Date(timeIntervalSinceReferenceDate: 20)
        )
        let appAutomation = AutomationRule(
            id: UUID(),
            name: "Morning Work",
            enabled: true,
            presetID: appPreset.id,
            trigger: .power(.connected),
            createdAt: Date(timeIntervalSinceReferenceDate: 30),
            updatedAt: Date(timeIntervalSinceReferenceDate: 30),
            lastRunAt: nil
        )
        let appHistory = RecentSessionEntry(
            id: UUID(),
            startedAt: Date(timeIntervalSinceReferenceDate: 100),
            endedAt: Date(timeIntervalSinceReferenceDate: 200),
            minutesRequested: 30,
            powerMode: .full,
            presetID: appPreset.id,
            presetName: appPreset.name,
            source: .app,
            automationRuleID: nil,
            automationRuleName: nil
        )
        let cliHistory = RecentSessionEntry(
            id: UUID(),
            startedAt: Date(timeIntervalSinceReferenceDate: 300),
            endedAt: Date(timeIntervalSinceReferenceDate: 360),
            minutesRequested: 15,
            powerMode: .system,
            presetID: nil,
            presetName: nil,
            source: .cli,
            automationRuleID: nil,
            automationRuleName: nil
        )
        let cliState = CaffeinateRecord(
            pid: 4242,
            startedAt: .now.addingTimeInterval(-300),
            endsAt: .now.addingTimeInterval(1_800),
            minutes: 30,
            powerMode: .full,
            presetID: nil,
            presetName: nil,
            source: .cli,
            automationRuleID: nil,
            automationRuleName: nil,
            backend: .subprocess
        )
        let appAutomationHistory = AutomationRunRecord(
            id: UUID(),
            ruleID: appAutomation.id,
            ruleName: appAutomation.name,
            firedAt: Date(timeIntervalSinceReferenceDate: 400),
            outcome: .started,
            message: "Started",
            calendarEventID: nil
        )
        let cliAutomationHistory = AutomationRunRecord(
            id: UUID(),
            ruleID: UUID(),
            ruleName: "CLI Rule",
            firedAt: Date(timeIntervalSinceReferenceDate: 450),
            outcome: .failed,
            message: "Missing preset",
            calendarEventID: nil
        )

        try writeJSON([appPreset], to: sandboxDirectory.appending(path: "presets.json"))
        try writeJSON([cliPreset], to: standaloneDirectory.appending(path: "presets.json"))
        try writeJSON([appAutomation], to: sandboxDirectory.appending(path: "automations.json"))
        try writeJSON([appHistory], to: sandboxDirectory.appending(path: "history.json"))
        try writeJSON([cliHistory], to: standaloneDirectory.appending(path: "history.json"))
        try writeJSON(cliState, to: standaloneDirectory.appending(path: "state.json"))
        try writeJSON([appAutomationHistory], to: sandboxDirectory.appending(path: "automation-history.json"))
        try writeJSON([cliAutomationHistory], to: standaloneDirectory.appending(path: "automation-history.json"))

        let context = try SpotlightCaffeinatePaths.prepareStorage(
            fileManager: fileManager,
            environment: SpotlightCaffeinateStorageEnvironment(
                appGroupContainerDirectory: sharedGroupRoot,
                userApplicationSupportDirectory: userApplicationSupportDirectory,
                sandboxApplicationSupportDirectory: sandboxApplicationSupportDirectory
            )
        )

        let sharedDirectory = sharedGroupRoot.appending(path: SpotlightCaffeinatePaths.appDirectoryName, directoryHint: .isDirectory)
        let migratedPresets = try readJSON([CaffeinatePreset].self, from: sharedDirectory.appending(path: "presets.json"))
        let migratedAutomations = try readJSON([AutomationRule].self, from: sharedDirectory.appending(path: "automations.json"))
        let migratedHistory = try readJSON([RecentSessionEntry].self, from: sharedDirectory.appending(path: "history.json"))
        let migratedState = try readJSON(CaffeinateRecord.self, from: sharedDirectory.appending(path: "state.json"))
        let migratedAutomationHistory = try readJSON([AutomationRunRecord].self, from: sharedDirectory.appending(path: "automation-history.json"))

        #expect(context.usesSharedContainer)
        #expect(context.directory == sharedDirectory)
        #expect(migratedPresets == [appPreset])
        #expect(migratedAutomations == [appAutomation])
        #expect(migratedState.pid == cliState.pid)
        #expect(migratedState.backend == .subprocess)
        #expect(migratedHistory.count == 2)
        #expect(migratedHistory.map(\.source) == [.cli, .app])
        #expect(migratedAutomationHistory.count == 2)
        #expect(migratedAutomationHistory.map(\.ruleName) == ["CLI Rule", "Morning Work"])
    }

    @Test
    func sharedContainerSkipsMigrationWhenAlreadyInitialized() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let sharedGroupRoot = root.appending(path: "AppGroup", directoryHint: .isDirectory)
        let userApplicationSupportDirectory = root.appending(path: "Application Support", directoryHint: .isDirectory)
        let sandboxApplicationSupportDirectory = root
            .appending(path: "Containers/io.taylorfinklea.spotlightcaffeinate/Data/Library/Application Support", directoryHint: .isDirectory)
        let sharedDirectory = sharedGroupRoot.appending(path: SpotlightCaffeinatePaths.appDirectoryName, directoryHint: .isDirectory)
        let standaloneDirectory = userApplicationSupportDirectory.appending(path: SpotlightCaffeinatePaths.appDirectoryName, directoryHint: .isDirectory)

        try fileManager.createDirectory(at: sharedDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: standaloneDirectory, withIntermediateDirectories: true)

        let existingPreset = CaffeinatePreset(
            id: UUID(),
            name: "Shared 90m",
            minutes: 90,
            powerMode: .display,
            isPinned: true,
            sortOrder: 0,
            createdAt: Date(timeIntervalSinceReferenceDate: 10),
            updatedAt: Date(timeIntervalSinceReferenceDate: 10)
        )
        let legacyPreset = CaffeinatePreset(
            id: UUID(),
            name: "Legacy 15m",
            minutes: 15,
            powerMode: .full,
            isPinned: true,
            sortOrder: 0,
            createdAt: Date(timeIntervalSinceReferenceDate: 20),
            updatedAt: Date(timeIntervalSinceReferenceDate: 20)
        )

        try writeJSON([existingPreset], to: sharedDirectory.appending(path: "presets.json"))
        try writeJSON([legacyPreset], to: standaloneDirectory.appending(path: "presets.json"))

        _ = try SpotlightCaffeinatePaths.prepareStorage(
            fileManager: fileManager,
            environment: SpotlightCaffeinateStorageEnvironment(
                appGroupContainerDirectory: sharedGroupRoot,
                userApplicationSupportDirectory: userApplicationSupportDirectory,
                sandboxApplicationSupportDirectory: sandboxApplicationSupportDirectory
            )
        )

        let migratedPresets = try readJSON([CaffeinatePreset].self, from: sharedDirectory.appending(path: "presets.json"))
        #expect(migratedPresets == [existingPreset])
        #expect(!fileManager.fileExists(atPath: sharedDirectory.appending(path: "state.json").path))
    }

    @Test
    func legacyFallbackWarnsWhenSandboxedAppStoreExists() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let userApplicationSupportDirectory = root.appending(path: "Application Support", directoryHint: .isDirectory)
        let sandboxApplicationSupportDirectory = root
            .appending(path: "Containers/io.taylorfinklea.spotlightcaffeinate/Data/Library/Application Support", directoryHint: .isDirectory)
        let sandboxDirectory = sandboxApplicationSupportDirectory.appending(path: SpotlightCaffeinatePaths.appDirectoryName, directoryHint: .isDirectory)

        try fileManager.createDirectory(at: sandboxDirectory, withIntermediateDirectories: true)

        let context = try SpotlightCaffeinatePaths.prepareStorage(
            fileManager: fileManager,
            environment: SpotlightCaffeinateStorageEnvironment(
                appGroupContainerDirectory: nil,
                userApplicationSupportDirectory: userApplicationSupportDirectory,
                sandboxApplicationSupportDirectory: sandboxApplicationSupportDirectory
            )
        )

        #expect(!context.usesSharedContainer)
        #expect(context.shouldWarnStandaloneCLIAboutUnsyncedApp)
        #expect(context.directory == userApplicationSupportDirectory.appending(path: SpotlightCaffeinatePaths.appDirectoryName, directoryHint: .isDirectory))
    }
}

private func writeJSON<T: Encodable>(_ value: T, to url: URL) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let data = try encoder.encode(value)
    try data.write(to: url, options: .atomic)
}

private func readJSON<T: Decodable>(_ type: T.Type, from url: URL) throws -> T {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let data = try Data(contentsOf: url)
    return try decoder.decode(type, from: data)
}
