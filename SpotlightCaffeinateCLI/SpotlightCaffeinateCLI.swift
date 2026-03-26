import Darwin
import Foundation

@main
struct SpotlightCaffeinateCLI {
    static func main() async {
        let executableName = URL(fileURLWithPath: CommandLine.arguments.first ?? "spotlight-caffeinate-cli").lastPathComponent
        let exitCode = await run(
            arguments: Array(CommandLine.arguments.dropFirst()),
            executableName: executableName
        )
        Darwin.exit(exitCode)
    }

    private static func run(arguments: [String], executableName: String) async -> Int32 {
        do {
            let command = try SpotlightCaffeinateCLIParser.parse(arguments: arguments)
            return try await execute(command)
        } catch {
            if case CLIParseError.missingCommand = error {
                printUsage(executableName: executableName)
                return 0
            }

            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            if !message.isEmpty {
                fputs("Error: \(message)\n", stderr)
            }

            printUsage(executableName: executableName)
            return 1
        }
    }

    private static func execute(_ command: SpotlightCaffeinateCLICommand) async throws -> Int32 {
        let service = CaffeinateService.cliShared
        let automationService = AutomationService.cliShared

        switch command {
        case .start(let minutes, let powerMode, let presetName):
            let snapshot: CaffeinateSnapshot
            if let presetName {
                snapshot = try await service.startPreset(named: presetName, source: .cli)
                print("Started preset '\(presetName)'.")
            } else if let minutes {
                let selectedMode = powerMode ?? .full
                snapshot = try await service.start(minutes: minutes, powerMode: selectedMode, source: .cli)
                print("Started caffeinate for \(minutes) minute\(minutes == 1 ? "" : "s") in \(selectedMode.rawValue) mode.")
            } else {
                throw CLIParseError.missingValue("minutes")
            }
            print(renderStatus(snapshot, now: .now))
            return 0

        case .stop:
            let previousSnapshot = try await service.status()
            let snapshot = try await service.stop()
            if previousSnapshot.isRunning {
                print("Stopped caffeinate.")
            } else {
                print("Caffeinate is not running.")
            }
            print(renderStatus(snapshot, now: .now))
            return 0

        case .status(let json):
            let snapshot = try await service.status()
            if json {
                print(try CaffeinateCLIJSONFormatter.renderStatus(snapshot, now: .now))
            } else {
                print(renderStatus(snapshot, now: .now))
            }
            return 0

        case .watch:
            while true {
                let now = Date()
                let snapshot = try await service.status()
                renderWatch(snapshot, now: now)
                fflush(stdout)
                try await Task.sleep(for: .seconds(1))
            }

        case .extend(let minutes, let presetName):
            let snapshot: CaffeinateSnapshot
            if let presetName {
                snapshot = try await service.extendPreset(named: presetName, source: .cli)
                print("Extended caffeinate with preset '\(presetName)'.")
            } else if let minutes {
                snapshot = try await service.extend(minutes: minutes, source: .cli)
                print("Extended caffeinate by \(minutes) minute\(minutes == 1 ? "" : "s").")
            } else {
                throw CLIParseError.missingValue("minutes")
            }
            print(renderStatus(snapshot, now: .now))
            return 0

        case .history(let limit, let json):
            let history = try await service.recentSessions(limit: limit)
            if json {
                print(try CaffeinateCLIJSONFormatter.renderHistory(history))
            } else {
                print(renderHistory(history))
            }
            return 0

        case .presetsList(let json):
            let presets = try await service.presets()
            if json {
                print(try CaffeinateCLIJSONFormatter.renderPresets(presets))
            } else {
                print(renderPresets(presets))
            }
            return 0

        case .automationsList(let json):
            let rules = try await automationService.rules()
            let presets = try await service.presets()
            let summaries = automationSummaries(rules: rules, presets: presets)
            if json {
                print(try CaffeinateCLIJSONFormatter.renderAutomations(summaries))
            } else {
                print(renderAutomations(summaries))
            }
            return 0

        case .automationsHistory(let limit, let json):
            let history = try await automationService.runHistory(limit: limit)
            if json {
                print(try CaffeinateCLIJSONFormatter.renderAutomationHistory(history))
            } else {
                print(renderAutomationHistory(history))
            }
            return 0

        case .automationEnable(let value):
            let rule = try await automationService.rule(matching: value)
            _ = try await automationService.setRuleEnabled(id: rule.id, enabled: true)
            print("Enabled automation '\(rule.name)'.")
            return 0

        case .automationDisable(let value):
            let rule = try await automationService.rule(matching: value)
            _ = try await automationService.setRuleEnabled(id: rule.id, enabled: false)
            print("Disabled automation '\(rule.name)'.")
            return 0

        case .automationDelete(let value):
            let rule = try await automationService.rule(matching: value)
            _ = try await automationService.deleteRule(id: rule.id)
            print("Deleted automation '\(rule.name)'.")
            return 0

        case .automationAddSchedule(let name, let presetName, let weekdays, let hour, let minute):
            let preset = try await resolvePreset(named: presetName, service: service)
            _ = try await automationService.createRule(
                name: name,
                presetID: preset.id,
                trigger: .weekly(
                    WeeklyAutomationTrigger(
                        weekdays: weekdays,
                        hour: hour,
                        minute: minute
                    )
                ),
                enabled: true
            )
            print("Created scheduled automation '\(name)'.")
            return 0

        case .automationAddPower(let name, let presetName, let event):
            let preset = try await resolvePreset(named: presetName, service: service)
            _ = try await automationService.createRule(
                name: name,
                presetID: preset.id,
                trigger: .power(event),
                enabled: true
            )
            print("Created power automation '\(name)'.")
            return 0

        case .automationAddCalendar(let name, let presetName, let calendarNames, let startsBeforeMinutes, let titleContains):
            let preset = try await resolvePreset(named: presetName, service: service)
            let identifiers = try await resolveCalendarIdentifiers(named: calendarNames, automationService: automationService)
            _ = try await automationService.createRule(
                name: name,
                presetID: preset.id,
                trigger: .calendar(
                    CalendarAutomationTrigger(
                        calendarIdentifiers: identifiers,
                        startsBeforeMinutes: startsBeforeMinutes,
                        titleContains: titleContains
                    )
                ),
                enabled: true
            )
            print("Created calendar automation '\(name)'.")
            return 0
        }
    }

    private static func resolvePreset(named presetName: String, service: CaffeinateService) async throws -> CaffeinatePreset {
        let normalized = presetName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let preset = try await service.presets().first(where: { $0.name.caseInsensitiveCompare(normalized) == .orderedSame }) else {
            throw CaffeinateServiceError.presetNotFound(normalized)
        }
        return preset
    }

    private static func resolveCalendarIdentifiers(
        named calendarNames: [String],
        automationService: AutomationService
    ) async throws -> [String] {
        let currentState = await automationService.calendarAuthorizationState()
        let state: AutomationCalendarAuthorizationState
        switch currentState {
        case .granted:
            state = .granted
        case .notDetermined:
            state = try await automationService.requestCalendarAccess()
        case .denied:
            throw AutomationServiceError.calendarAccessDenied
        }

        guard state == .granted else {
            throw AutomationServiceError.calendarAccessDenied
        }

        let options = await automationService.availableCalendars()
        return try calendarNames.map { name in
            let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let option = options.first(where: { $0.title.caseInsensitiveCompare(normalized) == .orderedSame }) else {
                throw AutomationServiceError.calendarNotFound(normalized)
            }
            return option.id
        }
    }

    private static func automationSummaries(
        rules: [AutomationRule],
        presets: [CaffeinatePreset]
    ) -> [AutomationRuleSummary] {
        rules.map { rule in
            AutomationRuleSummary(
                id: rule.id,
                name: rule.name,
                enabled: rule.enabled,
                presetID: rule.presetID,
                presetName: presets.first(where: { $0.id == rule.presetID })?.name,
                trigger: rule.trigger,
                createdAt: rule.createdAt,
                updatedAt: rule.updatedAt,
                lastRunAt: rule.lastRunAt
            )
        }
    }

    private static func renderStatus(_ snapshot: CaffeinateSnapshot, now: Date) -> String {
        CaffeinateStatusFormatter.renderStatus(snapshot, now: now) {
            timestampFormatter.string(from: $0)
        }
    }

    private static func renderWatch(_ snapshot: CaffeinateSnapshot, now: Date) {
        print(
            CaffeinateStatusFormatter.renderWatchScreen(snapshot, now: now) {
                timestampFormatter.string(from: $0)
            },
            terminator: "\n"
        )
    }

    static func usageText(executableName: String) -> String {
        """
        \(executableName)

        Usage:
          \(executableName) start <minutes> [--mode <display|system|full>]
          \(executableName) start --preset <name>
          \(executableName) stop
          \(executableName) status [--json]
          \(executableName) watch
          \(executableName) extend <minutes>
          \(executableName) extend --preset <name>
          \(executableName) history [--limit N] [--json]
          \(executableName) presets list [--json]
          \(executableName) automations list [--json]
          \(executableName) automations history [--limit N] [--json]
          \(executableName) automations enable <id-or-name>
          \(executableName) automations disable <id-or-name>
          \(executableName) automations delete <id-or-name>
          \(executableName) automations add schedule --name <name> --preset <preset> --days Mon,Tue --time 09:00
          \(executableName) automations add power --name <name> --preset <preset> --when connected|disconnected
          \(executableName) automations add calendar --name <name> --preset <preset> --calendar <name> [--calendar <name> ...] [--starts-before <minutes>] [--title-contains <text>]
        """
    }

    private static func printUsage(executableName: String) {
        print(usageText(executableName: executableName))
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()

    private static func renderHistory(_ history: [RecentSessionEntry]) -> String {
        guard !history.isEmpty else {
            return "No recent sessions."
        }

        return history.enumerated().map { index, entry in
            let ending = timestampFormatter.string(from: entry.endedAt)
            return "\(index + 1). \(entry.displayName) • \(entry.minutesRequested)m • \(entry.powerMode.rawValue) • ended \(ending)"
        }
        .joined(separator: "\n")
    }

    private static func renderPresets(_ presets: [CaffeinatePreset]) -> String {
        guard !presets.isEmpty else {
            return "No presets."
        }

        return presets.map { preset in
            let pinned = preset.isPinned ? "pinned" : "unpinned"
            return "\(preset.name) • \(preset.minutes)m • \(preset.powerMode.rawValue) • \(pinned)"
        }
        .joined(separator: "\n")
    }

    private static func renderAutomations(_ summaries: [AutomationRuleSummary]) -> String {
        guard !summaries.isEmpty else {
            return "No automations."
        }

        return summaries.map { summary in
            let enabled = summary.enabled ? "enabled" : "disabled"
            let preset = summary.presetName ?? summary.presetID.uuidString
            return "\(summary.name) • \(preset) • \(renderTrigger(summary.trigger)) • \(enabled)"
        }
        .joined(separator: "\n")
    }

    private static func renderAutomationHistory(_ records: [AutomationRunRecord]) -> String {
        guard !records.isEmpty else {
            return "No automation runs."
        }

        return records.enumerated().map { index, record in
            let firedAt = timestampFormatter.string(from: record.firedAt)
            return "\(index + 1). \(record.ruleName) • \(record.outcome.title) • \(firedAt)\n   \(record.message)"
        }
        .joined(separator: "\n")
    }

    private static func renderTrigger(_ trigger: AutomationTrigger) -> String {
        switch trigger {
        case .weekly(let trigger):
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            let date = Calendar.current.date(from: DateComponents(hour: trigger.hour, minute: trigger.minute)) ?? .now
            let dayText = trigger.normalizedWeekdays.map(\.shortLabel).joined(separator: ",")
            return "\(dayText) @ \(formatter.string(from: date))"
        case .power(let event):
            return event.title
        case .calendar(let trigger):
            let filter = trigger.normalizedTitleContains.map { " • '\($0)'" } ?? ""
            return "\(trigger.calendarIdentifiers.count) calendars • \(trigger.startsBeforeMinutes)m before\(filter)"
        }
    }
}
