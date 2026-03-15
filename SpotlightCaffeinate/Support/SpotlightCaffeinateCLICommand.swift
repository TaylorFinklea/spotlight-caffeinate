import Foundation

enum CLIParseError: LocalizedError, Equatable {
    case missingCommand
    case invalidCommand(String)
    case invalidOption(String)
    case missingValue(String)
    case invalidMinutes(String)
    case invalidLimit(String)
    case invalidMode(String)
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
            try requireNoRemainder(remainder, command: command)
            return .stop
        case "status":
            return .status(json: try parseJSONFlag(arguments: remainder))
        case "watch":
            try requireNoRemainder(remainder, command: command)
            return .watch
        case "extend":
            return try parseExtend(arguments: remainder)
        case "history":
            return try parseHistory(arguments: remainder)
        case "presets":
            return try parsePresets(arguments: remainder)
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
                guard index < arguments.count else {
                    throw CLIParseError.missingValue("--preset")
                }
                presetName = arguments[index]
            case "--mode":
                index += 1
                guard index < arguments.count else {
                    throw CLIParseError.missingValue("--mode")
                }
                guard let parsedMode = PowerMode(rawValue: arguments[index].lowercased()) else {
                    throw CLIParseError.invalidMode(arguments[index])
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
                guard index < arguments.count else {
                    throw CLIParseError.missingValue("--preset")
                }
                presetName = arguments[index]
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
                guard index < arguments.count else {
                    throw CLIParseError.missingValue("--limit")
                }
                guard let parsed = Int(arguments[index]), parsed > 0 else {
                    throw CLIParseError.invalidLimit(arguments[index])
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

    private static func parseMinutes(_ value: String) throws -> Int {
        guard let minutes = Int(value), (1...1440).contains(minutes) else {
            throw CLIParseError.invalidMinutes(value)
        }

        return minutes
    }

    private static func requireNoRemainder(_ remainder: [String], command: String) throws {
        guard remainder.isEmpty else {
            throw CLIParseError.invalidOption(remainder[0])
        }
    }
}
