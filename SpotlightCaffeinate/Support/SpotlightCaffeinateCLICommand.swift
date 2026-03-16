import Foundation

enum CLIParseError: LocalizedError, Equatable {
    case missingCommand
    case invalidCommand(String)
    case invalidOption(String)
    case missingValue(String)
    case invalidMinutes(String)
    case invalidLimit(String)
    case invalidMode(String)
    case invalidDay(String)
    case invalidTime(String)
    case invalidPowerEvent(String)
    case missingSubcommand(String)
    case conflictingStartOptions
    case conflictingExtendOptions

    var errorDescription: String? {
        switch self {
        case .missingCommand:
            return nil
        case .invalidCommand(let command):
            return "Unknown command '\(command)'."
        case .invalidOption(let option):
            return "Unknown option '\(option)'."
        case .missingValue(let option):
            return "Missing value for \(option)."
        case .invalidMinutes(let value):
            return "Invalid minutes value '\(value)'. Use a whole number between 1 and 1440."
        case .invalidLimit(let value):
            return "Invalid history limit '\(value)'. Use a whole number greater than 0."
        case .invalidMode(let value):
            return "Invalid power mode '\(value)'. Use display, system, or full."
        case .invalidDay(let value):
            return "Invalid weekday '\(value)'. Use comma-separated values like Mon,Tue."
        case .invalidTime(let value):
            return "Invalid time '\(value)'. Use HH:MM in 24-hour time."
        case .invalidPowerEvent(let value):
            return "Invalid power event '\(value)'. Use connected or disconnected."
        case .missingSubcommand(let command):
            return "Missing subcommand for '\(command)'."
        case .conflictingStartOptions:
            return "Use either a minutes value or --preset for start, not both."
        case .conflictingExtendOptions:
            return "Use either a minutes value or --preset for extend, not both."
        }
    }
}

enum SpotlightCaffeinateCLICommand: Equatable {
    case start(minutes: Int?, powerMode: PowerMode?, presetName: String?)
    case stop
    case status(json: Bool)
    case watch
    case extend(minutes: Int?, presetName: String?)
    case history(limit: Int, json: Bool)
    case presetsList(json: Bool)
    case automationsList(json: Bool)
    case automationsHistory(limit: Int, json: Bool)
    case automationEnable(String)
    case automationDisable(String)
    case automationDelete(String)
    case automationAddSchedule(name: String, presetName: String, weekdays: [AutomationWeekday], hour: Int, minute: Int)
    case automationAddPower(name: String, presetName: String, event: AutomationPowerEvent)
    case automationAddCalendar(name: String, presetName: String, calendarNames: [String], startsBeforeMinutes: Int, titleContains: String?)
}

struct SpotlightCaffeinateCLIParser {
    static func parse(arguments: [String]) throws -> SpotlightCaffeinateCLICommand {
        guard let command = arguments.first else {
            throw CLIParseError.missingCommand
        }

        let remainder = Array(arguments.dropFirst())
        switch command {
        case "help", "--help", "-h":
            throw CLIParseError.missingCommand
        case "start":
            return try parseStart(arguments: remainder)
        case "stop":
            try requireNoRemainder(remainder)
            return .stop
        case "status":
            return .status(json: try parseJSONFlag(arguments: remainder))
        case "watch":
            try requireNoRemainder(remainder)
            return .watch
        case "extend":
            return try parseExtend(arguments: remainder)
        case "history":
            return try parseHistory(arguments: remainder)
        case "presets":
            return try parsePresets(arguments: remainder)
        case "automations":
            return try parseAutomations(arguments: remainder)
        default:
            throw CLIParseError.invalidCommand(command)
        }
    }

    private static func parseStart(arguments: [String]) throws -> SpotlightCaffeinateCLICommand {
        var minutes: Int?
        var presetName: String?
        var powerMode: PowerMode?
        var index = 0

        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--preset":
                index += 1
                presetName = try value(at: index, in: arguments, option: "--preset")
            case "--mode":
                index += 1
                let modeValue = try value(at: index, in: arguments, option: "--mode")
                guard let parsedMode = PowerMode(rawValue: modeValue.lowercased()) else {
                    throw CLIParseError.invalidMode(modeValue)
                }
                powerMode = parsedMode
            default:
                if argument.hasPrefix("--") {
                    throw CLIParseError.invalidOption(argument)
                }
                guard minutes == nil else {
                    throw CLIParseError.conflictingStartOptions
                }
                minutes = try parseMinutes(argument)
            }
            index += 1
        }

        if minutes != nil, presetName != nil {
            throw CLIParseError.conflictingStartOptions
        }

        if minutes == nil, presetName == nil {
            throw CLIParseError.missingValue("minutes")
        }

        if presetName != nil, powerMode != nil {
            throw CLIParseError.conflictingStartOptions
        }

        return .start(minutes: minutes, powerMode: powerMode, presetName: presetName)
    }

    private static func parseExtend(arguments: [String]) throws -> SpotlightCaffeinateCLICommand {
        var minutes: Int?
        var presetName: String?
        var index = 0

        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--preset":
                index += 1
                presetName = try value(at: index, in: arguments, option: "--preset")
            default:
                if argument.hasPrefix("--") {
                    throw CLIParseError.invalidOption(argument)
                }
                guard minutes == nil else {
                    throw CLIParseError.conflictingExtendOptions
                }
                minutes = try parseMinutes(argument)
            }
            index += 1
        }

        if minutes != nil, presetName != nil {
            throw CLIParseError.conflictingExtendOptions
        }

        if minutes == nil, presetName == nil {
            throw CLIParseError.missingValue("minutes")
        }

        return .extend(minutes: minutes, presetName: presetName)
    }

    private static func parseHistory(arguments: [String]) throws -> SpotlightCaffeinateCLICommand {
        var limit = 20
        var json = false
        var index = 0

        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--json":
                json = true
            case "--limit":
                index += 1
                let value = try self.value(at: index, in: arguments, option: "--limit")
                guard let parsed = Int(value), parsed > 0 else {
                    throw CLIParseError.invalidLimit(value)
                }
                limit = parsed
            default:
                throw CLIParseError.invalidOption(argument)
            }
            index += 1
        }

        return .history(limit: limit, json: json)
    }

    private static func parsePresets(arguments: [String]) throws -> SpotlightCaffeinateCLICommand {
        guard let subcommand = arguments.first else {
            throw CLIParseError.missingSubcommand("presets")
        }

        guard subcommand == "list" else {
            throw CLIParseError.invalidCommand("presets \(subcommand)")
        }

        return .presetsList(json: try parseJSONFlag(arguments: Array(arguments.dropFirst())))
    }

    private static func parseAutomations(arguments: [String]) throws -> SpotlightCaffeinateCLICommand {
        guard let subcommand = arguments.first else {
            throw CLIParseError.missingSubcommand("automations")
        }

        let remainder = Array(arguments.dropFirst())
        switch subcommand {
        case "list":
            return .automationsList(json: try parseJSONFlag(arguments: remainder))
        case "history":
            return try parseAutomationHistory(arguments: remainder)
        case "enable":
            guard let value = remainder.first else {
                throw CLIParseError.missingValue("automation")
            }
            try requireNoRemainder(Array(remainder.dropFirst()))
            return .automationEnable(value)
        case "disable":
            guard let value = remainder.first else {
                throw CLIParseError.missingValue("automation")
            }
            try requireNoRemainder(Array(remainder.dropFirst()))
            return .automationDisable(value)
        case "delete":
            guard let value = remainder.first else {
                throw CLIParseError.missingValue("automation")
            }
            try requireNoRemainder(Array(remainder.dropFirst()))
            return .automationDelete(value)
        case "add":
            return try parseAutomationAdd(arguments: remainder)
        default:
            throw CLIParseError.invalidCommand("automations \(subcommand)")
        }
    }

    private static func parseAutomationHistory(arguments: [String]) throws -> SpotlightCaffeinateCLICommand {
        var limit = 20
        var json = false
        var index = 0

        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--json":
                json = true
            case "--limit":
                index += 1
                let value = try self.value(at: index, in: arguments, option: "--limit")
                guard let parsed = Int(value), parsed > 0 else {
                    throw CLIParseError.invalidLimit(value)
                }
                limit = parsed
            default:
                throw CLIParseError.invalidOption(argument)
            }
            index += 1
        }

        return .automationsHistory(limit: limit, json: json)
    }

    private static func parseAutomationAdd(arguments: [String]) throws -> SpotlightCaffeinateCLICommand {
        guard let subcommand = arguments.first else {
            throw CLIParseError.missingSubcommand("automations add")
        }

        let remainder = Array(arguments.dropFirst())
        switch subcommand {
        case "schedule":
            return try parseScheduleAutomation(arguments: remainder)
        case "power":
            return try parsePowerAutomation(arguments: remainder)
        case "calendar":
            return try parseCalendarAutomation(arguments: remainder)
        default:
            throw CLIParseError.invalidCommand("automations add \(subcommand)")
        }
    }

    private static func parseScheduleAutomation(arguments: [String]) throws -> SpotlightCaffeinateCLICommand {
        var name: String?
        var presetName: String?
        var weekdays: [AutomationWeekday] = []
        var hour: Int?
        var minute: Int?
        var index = 0

        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--name":
                index += 1
                name = try value(at: index, in: arguments, option: "--name")
            case "--preset":
                index += 1
                presetName = try value(at: index, in: arguments, option: "--preset")
            case "--days":
                index += 1
                weekdays = try parseDays(value(at: index, in: arguments, option: "--days"))
            case "--time":
                index += 1
                (hour, minute) = try parseTime(value(at: index, in: arguments, option: "--time"))
            default:
                throw CLIParseError.invalidOption(argument)
            }
            index += 1
        }

        guard let name else { throw CLIParseError.missingValue("--name") }
        guard let presetName else { throw CLIParseError.missingValue("--preset") }
        guard !weekdays.isEmpty else { throw CLIParseError.missingValue("--days") }
        guard let hour, let minute else { throw CLIParseError.missingValue("--time") }

        return .automationAddSchedule(name: name, presetName: presetName, weekdays: weekdays, hour: hour, minute: minute)
    }

    private static func parsePowerAutomation(arguments: [String]) throws -> SpotlightCaffeinateCLICommand {
        var name: String?
        var presetName: String?
        var event: AutomationPowerEvent?
        var index = 0

        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--name":
                index += 1
                name = try value(at: index, in: arguments, option: "--name")
            case "--preset":
                index += 1
                presetName = try value(at: index, in: arguments, option: "--preset")
            case "--when":
                index += 1
                let value = try value(at: index, in: arguments, option: "--when")
                guard let parsed = AutomationPowerEvent(rawValue: value.lowercased()) else {
                    throw CLIParseError.invalidPowerEvent(value)
                }
                event = parsed
            default:
                throw CLIParseError.invalidOption(argument)
            }
            index += 1
        }

        guard let name else { throw CLIParseError.missingValue("--name") }
        guard let presetName else { throw CLIParseError.missingValue("--preset") }
        guard let event else { throw CLIParseError.missingValue("--when") }

        return .automationAddPower(name: name, presetName: presetName, event: event)
    }

    private static func parseCalendarAutomation(arguments: [String]) throws -> SpotlightCaffeinateCLICommand {
        var name: String?
        var presetName: String?
        var calendarNames: [String] = []
        var startsBeforeMinutes = 0
        var titleContains: String?
        var index = 0

        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--name":
                index += 1
                name = try value(at: index, in: arguments, option: "--name")
            case "--preset":
                index += 1
                presetName = try value(at: index, in: arguments, option: "--preset")
            case "--calendar":
                index += 1
                calendarNames.append(try value(at: index, in: arguments, option: "--calendar"))
            case "--starts-before":
                index += 1
                let value = try value(at: index, in: arguments, option: "--starts-before")
                guard let parsed = Int(value), (0...240).contains(parsed) else {
                    throw CLIParseError.invalidMinutes(value)
                }
                startsBeforeMinutes = parsed
            case "--title-contains":
                index += 1
                titleContains = try value(at: index, in: arguments, option: "--title-contains")
            default:
                throw CLIParseError.invalidOption(argument)
            }
            index += 1
        }

        guard let name else { throw CLIParseError.missingValue("--name") }
        guard let presetName else { throw CLIParseError.missingValue("--preset") }
        guard !calendarNames.isEmpty else { throw CLIParseError.missingValue("--calendar") }

        return .automationAddCalendar(
            name: name,
            presetName: presetName,
            calendarNames: calendarNames,
            startsBeforeMinutes: startsBeforeMinutes,
            titleContains: titleContains
        )
    }

    private static func parseJSONFlag(arguments: [String]) throws -> Bool {
        guard arguments.count <= 1 else {
            throw CLIParseError.invalidOption(arguments[1])
        }

        guard let first = arguments.first else {
            return false
        }

        guard first == "--json" else {
            throw CLIParseError.invalidOption(first)
        }

        return true
    }

    private static func parseDays(_ value: String) throws -> [AutomationWeekday] {
        let weekdays = try value
            .split(separator: ",")
            .map { raw -> AutomationWeekday in
                let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                switch trimmed {
                case "sun", "sunday": return .sunday
                case "mon", "monday": return .monday
                case "tue", "tues", "tuesday": return .tuesday
                case "wed", "wednesday": return .wednesday
                case "thu", "thur", "thurs", "thursday": return .thursday
                case "fri", "friday": return .friday
                case "sat", "saturday": return .saturday
                default:
                    throw CLIParseError.invalidDay(String(raw))
                }
            }
        return Array(Set(weekdays)).sorted { $0.rawValue < $1.rawValue }
    }

    private static func parseTime(_ value: String) throws -> (Int, Int) {
        let parts = value.split(separator: ":")
        guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]), (0...23).contains(hour), (0...59).contains(minute) else {
            throw CLIParseError.invalidTime(value)
        }

        return (hour, minute)
    }

    private static func parseMinutes(_ value: String) throws -> Int {
        guard let minutes = Int(value), (1...1440).contains(minutes) else {
            throw CLIParseError.invalidMinutes(value)
        }

        return minutes
    }

    private static func value(at index: Int, in arguments: [String], option: String) throws -> String {
        guard index < arguments.count else {
            throw CLIParseError.missingValue(option)
        }

        return arguments[index]
    }

    private static func requireNoRemainder(_ remainder: [String]) throws {
        guard remainder.isEmpty else {
            throw CLIParseError.invalidOption(remainder[0])
        }
    }
}
