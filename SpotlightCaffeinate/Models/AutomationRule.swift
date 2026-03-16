import Foundation

enum AutomationTriggerKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case weekly
    case power
    case calendar

    var id: String { rawValue }

    var title: String {
        switch self {
        case .weekly:
            return "Weekly Schedule"
        case .power:
            return "Power Change"
        case .calendar:
            return "Calendar Event"
        }
    }
}

enum AutomationWeekday: Int, Codable, CaseIterable, Identifiable, Sendable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7

    var id: Int { rawValue }

    var shortLabel: String {
        switch self {
        case .sunday: return "Sun"
        case .monday: return "Mon"
        case .tuesday: return "Tue"
        case .wednesday: return "Wed"
        case .thursday: return "Thu"
        case .friday: return "Fri"
        case .saturday: return "Sat"
        }
    }
}

enum AutomationPowerEvent: String, Codable, CaseIterable, Identifiable, Sendable {
    case connected
    case disconnected

    var id: String { rawValue }

    var title: String {
        switch self {
        case .connected:
            return "Power Connected"
        case .disconnected:
            return "Power Disconnected"
        }
    }
}

struct WeeklyAutomationTrigger: Codable, Equatable, Sendable {
    var weekdays: [AutomationWeekday]
    var hour: Int
    var minute: Int

    var normalizedWeekdays: [AutomationWeekday] {
        Array(Set(weekdays)).sorted { $0.rawValue < $1.rawValue }
    }

    func isDue(at date: Date, calendar: Calendar = .current) -> Bool {
        let components = calendar.dateComponents([.weekday, .hour, .minute], from: date)
        guard
            let weekday = components.weekday.flatMap(AutomationWeekday.init(rawValue:)),
            let hour = components.hour,
            let minute = components.minute
        else {
            return false
        }

        return normalizedWeekdays.contains(weekday) && self.hour == hour && self.minute == minute
    }
}

struct CalendarAutomationTrigger: Codable, Equatable, Sendable {
    var calendarIdentifiers: [String]
    var startsBeforeMinutes: Int
    var titleContains: String?

    var normalizedTitleContains: String? {
        let trimmed = titleContains?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}

enum AutomationTrigger: Codable, Equatable, Sendable {
    case weekly(WeeklyAutomationTrigger)
    case power(AutomationPowerEvent)
    case calendar(CalendarAutomationTrigger)

    var kind: AutomationTriggerKind {
        switch self {
        case .weekly:
            return .weekly
        case .power:
            return .power
        case .calendar:
            return .calendar
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case weekly
        case power
        case calendar
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(AutomationTriggerKind.self, forKey: .type)

        switch kind {
        case .weekly:
            self = .weekly(try container.decode(WeeklyAutomationTrigger.self, forKey: .weekly))
        case .power:
            self = .power(try container.decode(AutomationPowerEvent.self, forKey: .power))
        case .calendar:
            self = .calendar(try container.decode(CalendarAutomationTrigger.self, forKey: .calendar))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .type)

        switch self {
        case .weekly(let trigger):
            try container.encode(trigger, forKey: .weekly)
        case .power(let event):
            try container.encode(event, forKey: .power)
        case .calendar(let trigger):
            try container.encode(trigger, forKey: .calendar)
        }
    }
}

struct AutomationRule: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var enabled: Bool
    var presetID: UUID
    var trigger: AutomationTrigger
    var createdAt: Date
    var updatedAt: Date
    var lastRunAt: Date?
}
