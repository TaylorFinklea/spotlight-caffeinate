import Darwin
import Foundation

private enum CLIError: LocalizedError {
    case missingCommand
    case invalidCommand(String)
    case missingMinutes
    case invalidMinutes(String)

    var errorDescription: String? {
        switch self {
        case .missingCommand:
            return nil
        case .invalidCommand(let command):
            return "Unknown command '\(command)'."
        case .missingMinutes:
            return "Missing minutes value. Usage: spotlight-caffeinate-cli start <minutes>"
        case .invalidMinutes(let value):
            return "Invalid minutes value '\(value)'. Use a whole number between 1 and 1440."
        }
    }
}

@main
struct SpotlightCaffeinateCLI {
    static func main() async {
        let exitCode = await run(arguments: Array(CommandLine.arguments.dropFirst()))
        Darwin.exit(exitCode)
    }

    private static func run(arguments: [String]) async -> Int32 {
        do {
            let command = try parseCommand(arguments)
            return try await execute(command)
        } catch {
            if case CLIError.missingCommand = error {
                printUsage()
                return 0
            }

            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            if !message.isEmpty {
                fputs("Error: \(message)\n", stderr)
            }

            printUsage()
            return 1
        }
    }

    private static func parseCommand(_ arguments: [String]) throws -> Command {
        guard let command = arguments.first else {
            throw CLIError.missingCommand
        }

        switch command {
        case "help", "--help", "-h":
            throw CLIError.missingCommand
        case "start":
            guard let value = arguments.dropFirst().first else {
                throw CLIError.missingMinutes
            }

            guard let minutes = Int(value) else {
                throw CLIError.invalidMinutes(value)
            }

            return .start(minutes)
        case "stop":
            return .stop
        case "status":
            return .status
        case "watch":
            return .watch
        default:
            throw CLIError.invalidCommand(command)
        }
    }

    private static func execute(_ command: Command) async throws -> Int32 {
        let service = CaffeinateService.shared

        switch command {
        case .start(let minutes):
            let snapshot = try await service.start(minutes: minutes)
            print("Started caffeinate for \(minutes) minute\(minutes == 1 ? "" : "s").")
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

        case .status:
            let snapshot = try await service.status()
            print(renderStatus(snapshot, now: .now))
            return 0

        case .watch:
            while true {
                let now = Date()
                let snapshot = try await service.status()
                renderWatch(snapshot, now: now)
                fflush(stdout)
                try await Task.sleep(for: .seconds(1))
            }
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

    private static func printUsage() {
        print(
            """
            spotlight-caffeinate-cli

            Usage:
              spotlight-caffeinate-cli start <minutes>
              spotlight-caffeinate-cli stop
              spotlight-caffeinate-cli status
              spotlight-caffeinate-cli watch
            """
        )
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()

    private enum Command {
        case start(Int)
        case stop
        case status
        case watch
    }
}
