import AppIntents
import SwiftUI

struct PresetNameOptionsProvider: DynamicOptionsProvider {
    typealias Result = ItemCollection<String>

    func results() async throws -> ItemCollection<String> {
        let presets = try await CaffeinateService.shared.presets()

        guard !presets.isEmpty else {
            return .empty
        }

        let items = presets.map { preset in
            Item(
                preset.name,
                title: LocalizedStringResource(stringLiteral: preset.name),
                subtitle: LocalizedStringResource(stringLiteral: "\(preset.minutes)m • \(preset.powerMode.title)")
            )
        }

        return ItemCollection(sections: [
            ItemSection(items: items)
        ])
    }
}

struct StartCaffeinateIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Caffeinate"
    static let description = IntentDescription("Start caffeinate for a custom number of minutes.")
    static let supportedModes: IntentModes = .background

    @Parameter(
        title: "Minutes",
        default: 5,
        requestValueDialog: IntentDialog("How many minutes should your Mac stay awake?")
    )
    var minutes: Int

    static var parameterSummary: some ParameterSummary {
        Summary("Keep the Mac awake for \(\.$minutes) minutes")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let snapshot = try await CaffeinateService.shared.start(minutes: minutes, source: .spotlight)
        let now = Date()
        return .result(
            dialog: IntentDialog(stringLiteral: CaffeinateIntentMessageFormatter.startDialog(for: snapshot, fallbackMinutes: minutes)),
            view: CaffeinateStatusSnippetView(
                snapshot: snapshot,
                title: "Caffeinate Active",
                now: now
            )
        )
    }
}

struct StartPresetIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Preset"
    static let description = IntentDescription("Start caffeinate using one of your saved presets.")
    static let supportedModes: IntentModes = .background

    @Parameter(
        title: "Preset",
        requestValueDialog: IntentDialog("Which preset should run?"),
        optionsProvider: PresetNameOptionsProvider()
    )
    var presetName: String

    static var parameterSummary: some ParameterSummary {
        Summary("Start preset \(\.$presetName)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let snapshot = try await CaffeinateService.shared.startPreset(named: presetName, source: .spotlight)
        let now = Date()

        return .result(
            dialog: IntentDialog(stringLiteral: CaffeinateIntentMessageFormatter.startDialog(
                for: snapshot,
                fallbackMinutes: snapshot.minutesRequested ?? 0
            )),
            view: CaffeinateStatusSnippetView(
                snapshot: snapshot,
                title: "Caffeinate Active",
                now: now
            )
        )
    }
}

struct StopCaffeinateIntent: AppIntent {
    static let title: LocalizedStringResource = "Stop Caffeinate"
    static let description = IntentDescription("Stop the current caffeinate run.")
    static let supportedModes: IntentModes = .background

    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let snapshot = try await CaffeinateService.shared.status()

        guard snapshot.isRunning else {
            return .result(
                dialog: IntentDialog("Caffeinate is not running."),
                view: CaffeinateStatusSnippetView(
                    snapshot: .inactive,
                    title: "Caffeinate Idle",
                    now: .now
                )
            )
        }

        _ = try await CaffeinateService.shared.stop()
        return .result(
            dialog: IntentDialog("Caffeinate stopped."),
            view: CaffeinateStatusSnippetView(
                snapshot: .inactive,
                title: "Caffeinate Idle",
                now: .now
            )
        )
    }
}

struct CheckCaffeinateStatusIntent: AppIntent {
    static let title: LocalizedStringResource = "Check Caffeinate Status"
    static let description = IntentDescription("Check whether caffeinate is currently running.")
    static let supportedModes: IntentModes = .background

    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let snapshot = try await CaffeinateService.shared.status()
        let now = Date()

        if snapshot.isRunning {
            return .result(
                dialog: IntentDialog(stringLiteral: CaffeinateIntentMessageFormatter.statusDialog(for: snapshot, now: now)),
                view: CaffeinateStatusSnippetView(
                    snapshot: snapshot,
                    title: "Caffeinate Active",
                    now: now
                )
            )
        }

        return .result(
            dialog: "Caffeinate is not running.",
            view: CaffeinateStatusSnippetView(
                snapshot: .inactive,
                title: "Caffeinate Idle",
                now: now
            )
        )
    }
}

struct ExtendCaffeinateIntent: AppIntent {
    static let title: LocalizedStringResource = "Extend Caffeinate"
    static let description = IntentDescription("Extend the active caffeinate run by a number of minutes.")
    static let supportedModes: IntentModes = .background

    @Parameter(
        title: "Minutes",
        default: 15,
        requestValueDialog: IntentDialog("How many minutes should be added to the current caffeinate run?")
    )
    var minutes: Int

    static var parameterSummary: some ParameterSummary {
        Summary("Extend caffeinate by \(\.$minutes) minutes")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let snapshot = try await CaffeinateService.shared.extend(minutes: minutes, source: .spotlight)
        let now = Date()

        return .result(
            dialog: IntentDialog(stringLiteral: CaffeinateIntentMessageFormatter.extendDialog(for: snapshot, addedMinutes: minutes, now: now)),
            view: CaffeinateStatusSnippetView(
                snapshot: snapshot,
                title: "Caffeinate Active",
                now: now
            )
        )
    }
}

struct RestartLastSessionIntent: AppIntent {
    static let title: LocalizedStringResource = "Restart Last Session"
    static let description = IntentDescription("Restart the most recent completed caffeinate session.")
    static let supportedModes: IntentModes = .background

    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        do {
            let snapshot = try await CaffeinateService.shared.restartLast(source: .spotlight)
            let now = Date()

            return .result(
                dialog: IntentDialog("Last session restarted. \(CaffeinateIntentMessageFormatter.statusDialog(for: snapshot, now: now))"),
                view: CaffeinateStatusSnippetView(
                    snapshot: snapshot,
                    title: "Caffeinate Active",
                    now: now
                )
            )
        } catch CaffeinateServiceError.noRecentSession {
            let now = Date()
            return .result(
                dialog: IntentDialog(stringLiteral: CaffeinateIntentMessageFormatter.restartUnavailableDialog()),
                view: CaffeinateStatusSnippetView(
                    snapshot: .inactive,
                    title: "Caffeinate Idle",
                    now: now
                )
            )
        }
    }
}

struct SpotlightCaffeinateShortcuts: AppShortcutsProvider {
    static let shortcutTileColor: ShortcutTileColor = .orange

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartCaffeinateIntent(),
            phrases: [
                "Start \(.applicationName)",
                "Keep my Mac awake with \(.applicationName)"
            ],
            shortTitle: "Start",
            systemImageName: "play.circle"
        )
        AppShortcut(
            intent: StartPresetIntent(),
            phrases: [
                "Start preset with \(.applicationName)",
                "Run a caffeinate preset with \(.applicationName)"
            ],
            shortTitle: "Preset",
            systemImageName: "bookmark.circle"
        )
        AppShortcut(
            intent: StopCaffeinateIntent(),
            phrases: [
                "Stop \(.applicationName)",
                "Turn off \(.applicationName)"
            ],
            shortTitle: "Stop",
            systemImageName: "stop.circle"
        )
        AppShortcut(
            intent: CheckCaffeinateStatusIntent(),
            phrases: [
                "Check \(.applicationName) status",
                "Is \(.applicationName) running"
            ],
            shortTitle: "Status",
            systemImageName: "waveform.path.ecg"
        )
        AppShortcut(
            intent: ExtendCaffeinateIntent(),
            phrases: [
                "Extend \(.applicationName)",
                "Add time to \(.applicationName)"
            ],
            shortTitle: "Extend",
            systemImageName: "plus.circle"
        )
        AppShortcut(
            intent: RestartLastSessionIntent(),
            phrases: [
                "Restart last session with \(.applicationName)",
                "Restart last \(.applicationName) run"
            ],
            shortTitle: "Restart",
            systemImageName: "arrow.clockwise.circle"
        )
    }
}
