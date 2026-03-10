import AppIntents
import SwiftUI

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
        let snapshot = try await CaffeinateService.shared.start(minutes: minutes)
        return .result(
            dialog: IntentDialog("Caffeinate started for \(snapshot.minutesRequested ?? minutes) minutes."),
            view: CaffeinateStatusSnippetView(
                snapshot: snapshot,
                title: "Caffeinate Active",
                now: .now
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
                dialog: "Caffeinate is running with \(snapshot.remainingText(at: now)) remaining.",
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
    }
}
