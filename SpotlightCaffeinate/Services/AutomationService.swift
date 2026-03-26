import Foundation

enum AutomationServiceError: LocalizedError {
    case invalidRuleName
    case invalidWeekdays
    case invalidTime
    case invalidCalendarSelection
    case invalidLeadTime
    case calendarAccessDenied
    case calendarNotFound(String)
    case ruleNotFound(String)

    var errorDescription: String? {
        switch self {
        case .invalidRuleName:
            return "Automation names cannot be empty."
        case .invalidWeekdays:
            return "Choose at least one weekday for a scheduled automation."
        case .invalidTime:
            return "Choose a valid time for the automation."
        case .invalidCalendarSelection:
            return "Choose at least one calendar for a calendar automation."
        case .invalidLeadTime:
            return "Calendar lead time must be between 0 and 240 minutes."
        case .calendarAccessDenied:
            return "Calendar access is required for calendar automations."
        case .calendarNotFound(let value):
            return "Could not find a calendar named '\(value)'."
        case .ruleNotFound(let value):
            return "Could not find an automation named or identified as '\(value)'."
        }
    }
}

actor AutomationService {
    static let shared = AutomationService()
    static let cliShared = AutomationService(sessionService: .cliShared)

    private let automationsURL: URL
    private let historyURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let sessionService: CaffeinateService
    private let calendarStore: any AutomationCalendarStoreControlling
    private let now: @Sendable () -> Date

    private static let historyLimit = 50

    init(
        sessionService: CaffeinateService = .shared,
        calendarStore: any AutomationCalendarStoreControlling = SystemAutomationCalendarStore()
    ) {
        self.sessionService = sessionService
        self.calendarStore = calendarStore
        now = Date.init

        let appDirectory = SpotlightCaffeinatePaths.applicationSupportDirectory()
        automationsURL = appDirectory.appending(path: "automations.json")
        historyURL = appDirectory.appending(path: "automation-history.json")

        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    init(
        baseDirectory: URL,
        sessionService: CaffeinateService,
        calendarStore: any AutomationCalendarStoreControlling,
        now: @escaping @Sendable () -> Date
    ) {
        self.sessionService = sessionService
        self.calendarStore = calendarStore
        self.now = now

        let appDirectory = baseDirectory.appending(path: "SpotlightCaffeinate", directoryHint: .isDirectory)
        automationsURL = appDirectory.appending(path: "automations.json")
        historyURL = appDirectory.appending(path: "automation-history.json")

        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func rules() throws -> [AutomationRule] {
        try loadRules()
    }

    func runHistory(limit: Int = historyLimit) throws -> [AutomationRunRecord] {
        Array(try loadHistory().prefix(max(0, limit)))
    }

    func calendarAuthorizationState() -> AutomationCalendarAuthorizationState {
        calendarStore.authorizationState()
    }

    func requestCalendarAccess() async throws -> AutomationCalendarAuthorizationState {
        _ = try await calendarStore.requestAccess()
        return calendarStore.authorizationState()
    }

    func availableCalendars() -> [AutomationCalendarOption] {
        guard calendarAuthorizationState() == .granted else {
            return []
        }

        return calendarStore.calendars()
    }

    func createRule(
        name: String,
        presetID: UUID,
        trigger: AutomationTrigger,
        enabled: Bool
    ) throws -> [AutomationRule] {
        let currentDate = now()
        let validatedTrigger = try validate(trigger: trigger)
        let rule = AutomationRule(
            id: UUID(),
            name: try validate(ruleName: name),
            enabled: enabled,
            presetID: presetID,
            trigger: validatedTrigger,
            createdAt: currentDate,
            updatedAt: currentDate,
            lastRunAt: nil
        )

        var rules = try loadRules()
        rules.append(rule)
        return try persistRules(rules)
    }

    func updateRule(
        id: UUID,
        name: String,
        presetID: UUID,
        trigger: AutomationTrigger,
        enabled: Bool
    ) throws -> [AutomationRule] {
        var rules = try loadRules()
        guard let index = rules.firstIndex(where: { $0.id == id }) else {
            throw AutomationServiceError.ruleNotFound(id.uuidString)
        }

        rules[index].name = try validate(ruleName: name)
        rules[index].presetID = presetID
        rules[index].trigger = try validate(trigger: trigger)
        rules[index].enabled = enabled
        rules[index].updatedAt = now()
        return try persistRules(rules)
    }

    func deleteRule(id: UUID) throws -> [AutomationRule] {
        var rules = try loadRules()
        rules.removeAll { $0.id == id }
        return try persistRules(rules)
    }

    func setRuleEnabled(id: UUID, enabled: Bool) throws -> [AutomationRule] {
        var rules = try loadRules()
        guard let index = rules.firstIndex(where: { $0.id == id }) else {
            throw AutomationServiceError.ruleNotFound(id.uuidString)
        }

        rules[index].enabled = enabled
        rules[index].updatedAt = now()
        return try persistRules(rules)
    }

    func rule(matching value: String) throws -> AutomationRule {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let rules = try loadRules()

        if let id = UUID(uuidString: trimmed), let match = rules.first(where: { $0.id == id }) {
            return match
        }

        if let match = rules.first(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            return match
        }

        throw AutomationServiceError.ruleNotFound(trimmed)
    }

    func evaluateScheduleRules(at date: Date) async {
        do {
            let rules = try loadRules()
            for rule in rules where rule.enabled {
                guard case .weekly(let trigger) = rule.trigger, trigger.isDue(at: date) else {
                    continue
                }

                guard !didRun(rule: rule, duringSameMinuteAs: date) else {
                    continue
                }

                await execute(rule: rule, at: date, calendarEventID: nil)
            }
        } catch {
            // Swallow automation evaluation errors; they should not break the app loop.
        }
    }

    func evaluatePowerRules(for source: AutomationPowerSource, at date: Date) async {
        let event: AutomationPowerEvent = source == .connected ? .connected : .disconnected

        do {
            let rules = try loadRules()
            for rule in rules where rule.enabled {
                guard case .power(let configuredEvent) = rule.trigger, configuredEvent == event else {
                    continue
                }

                await execute(rule: rule, at: date, calendarEventID: nil)
            }
        } catch {
            // Swallow automation evaluation errors; they should not break the app loop.
        }
    }

    func evaluateCalendarRules(at date: Date) async {
        guard calendarAuthorizationState() == .granted else {
            return
        }

        let minuteStart = floorToMinute(date)
        let minuteEnd = minuteStart.addingTimeInterval(60)

        do {
            let rules = try loadRules()
            for rule in rules where rule.enabled {
                guard case .calendar(let trigger) = rule.trigger else {
                    continue
                }

                let lead = TimeInterval(trigger.startsBeforeMinutes * 60)
                let eventWindowStart = minuteStart.addingTimeInterval(lead)
                let eventWindowEnd = minuteEnd.addingTimeInterval(lead)
                let events = calendarStore.events(
                    in: trigger.calendarIdentifiers,
                    startingBetween: eventWindowStart,
                    and: eventWindowEnd
                )

                for event in events where matches(event: event, trigger: trigger) {
                    guard !didRun(ruleID: rule.id, calendarEventID: event.identifier, duringSameMinuteAs: date) else {
                        continue
                    }

                    await execute(rule: rule, at: date, calendarEventID: event.identifier)
                }
            }
        } catch {
            // Swallow automation evaluation errors; they should not break the app loop.
        }
    }

    private func execute(rule: AutomationRule, at date: Date, calendarEventID: String?) async {
        do {
            let preset = try await sessionService.presets().first(where: { $0.id == rule.presetID })
            guard let preset else {
                try mark(ruleID: rule.id, at: date)
                try appendRunRecord(
                    ruleID: rule.id,
                    ruleName: rule.name,
                    firedAt: date,
                    outcome: .skippedMissingPreset,
                    message: "Skipped because the preset for this automation could not be found.",
                    calendarEventID: calendarEventID
                )
                return
            }

            let current = try await sessionService.status()
            guard !current.isRunning(at: date) else {
                try mark(ruleID: rule.id, at: date)
                try appendRunRecord(
                    ruleID: rule.id,
                    ruleName: rule.name,
                    firedAt: date,
                    outcome: .skippedAlreadyRunning,
                    message: "Skipped because caffeinate is already running.",
                    calendarEventID: calendarEventID
                )
                return
            }

            _ = try await sessionService.start(
                minutes: preset.minutes,
                powerMode: preset.powerMode,
                presetID: preset.id,
                presetName: preset.name,
                source: .automation,
                automationRuleID: rule.id,
                automationRuleName: rule.name
            )

            try mark(ruleID: rule.id, at: date)
            try appendRunRecord(
                ruleID: rule.id,
                ruleName: rule.name,
                firedAt: date,
                outcome: .started,
                message: "Started preset '\(preset.name)'.",
                calendarEventID: calendarEventID
            )
        } catch {
            do {
                try mark(ruleID: rule.id, at: date)
                try appendRunRecord(
                    ruleID: rule.id,
                    ruleName: rule.name,
                    firedAt: date,
                    outcome: .failed,
                    message: error.localizedDescription,
                    calendarEventID: calendarEventID
                )
            } catch {
                // Ignore logging failures during automation execution.
            }
        }
    }

    private func validate(ruleName: String) throws -> String {
        let normalized = ruleName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            throw AutomationServiceError.invalidRuleName
        }

        return normalized
    }

    private func validate(trigger: AutomationTrigger) throws -> AutomationTrigger {
        switch trigger {
        case .weekly(let trigger):
            guard !trigger.normalizedWeekdays.isEmpty else {
                throw AutomationServiceError.invalidWeekdays
            }
            guard (0...23).contains(trigger.hour), (0...59).contains(trigger.minute) else {
                throw AutomationServiceError.invalidTime
            }

            return .weekly(
                WeeklyAutomationTrigger(
                    weekdays: trigger.normalizedWeekdays,
                    hour: trigger.hour,
                    minute: trigger.minute
                )
            )

        case .power:
            return trigger

        case .calendar(let trigger):
            guard !trigger.calendarIdentifiers.isEmpty else {
                throw AutomationServiceError.invalidCalendarSelection
            }
            guard (0...240).contains(trigger.startsBeforeMinutes) else {
                throw AutomationServiceError.invalidLeadTime
            }

            return .calendar(
                CalendarAutomationTrigger(
                    calendarIdentifiers: Array(Set(trigger.calendarIdentifiers)).sorted(),
                    startsBeforeMinutes: trigger.startsBeforeMinutes,
                    titleContains: trigger.normalizedTitleContains
                )
            )
        }
    }

    private func mark(ruleID: UUID, at date: Date) throws {
        var rules = try loadRules()
        guard let index = rules.firstIndex(where: { $0.id == ruleID }) else {
            return
        }

        rules[index].lastRunAt = date
        rules[index].updatedAt = date
        _ = try persistRules(rules)
    }

    private func didRun(rule: AutomationRule, duringSameMinuteAs date: Date) -> Bool {
        guard let lastRunAt = rule.lastRunAt else {
            return false
        }

        return floorToMinute(lastRunAt) == floorToMinute(date)
    }

    private func didRun(ruleID: UUID, calendarEventID: String, duringSameMinuteAs date: Date) -> Bool {
        (try? loadHistory().contains {
            $0.ruleID == ruleID &&
                $0.calendarEventID == calendarEventID &&
                floorToMinute($0.firedAt) == floorToMinute(date)
        }) ?? false
    }

    private func matches(event: AutomationCalendarEvent, trigger: CalendarAutomationTrigger) -> Bool {
        guard let titleContains = trigger.normalizedTitleContains else {
            return true
        }

        return event.title.localizedCaseInsensitiveContains(titleContains)
    }

    private func loadRules() throws -> [AutomationRule] {
        guard FileManager.default.fileExists(atPath: automationsURL.path) else {
            return []
        }

        do {
            let data = try Data(contentsOf: automationsURL)
            return try decoder.decode([AutomationRule].self, from: data)
        } catch {
            throw CaffeinateServiceError.failedToReadState(error.localizedDescription)
        }
    }

    private func persistRules(_ rules: [AutomationRule]) throws -> [AutomationRule] {
        do {
            try FileManager.default.createDirectory(at: automationsURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try encoder.encode(rules)
            try data.write(to: automationsURL, options: .atomic)
            return rules
        } catch {
            throw CaffeinateServiceError.failedToPersist(error.localizedDescription)
        }
    }

    private func loadHistory() throws -> [AutomationRunRecord] {
        guard FileManager.default.fileExists(atPath: historyURL.path) else {
            return []
        }

        do {
            let data = try Data(contentsOf: historyURL)
            return try decoder.decode([AutomationRunRecord].self, from: data)
        } catch {
            throw CaffeinateServiceError.failedToReadState(error.localizedDescription)
        }
    }

    private func appendRunRecord(
        ruleID: UUID,
        ruleName: String,
        firedAt: Date,
        outcome: AutomationRunOutcome,
        message: String,
        calendarEventID: String?
    ) throws {
        var history = try loadHistory()
        history.insert(
            AutomationRunRecord(
                id: UUID(),
                ruleID: ruleID,
                ruleName: ruleName,
                firedAt: firedAt,
                outcome: outcome,
                message: message,
                calendarEventID: calendarEventID
            ),
            at: 0
        )

        do {
            try FileManager.default.createDirectory(at: historyURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try encoder.encode(Array(history.prefix(Self.historyLimit)))
            try data.write(to: historyURL, options: .atomic)
        } catch {
            throw CaffeinateServiceError.failedToPersist(error.localizedDescription)
        }
    }

    private func floorToMinute(_ date: Date) -> Date {
        Date(timeIntervalSince1970: floor(date.timeIntervalSince1970 / 60) * 60)
    }
}
