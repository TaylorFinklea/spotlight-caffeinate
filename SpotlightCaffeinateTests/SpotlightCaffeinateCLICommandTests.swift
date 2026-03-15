import Foundation
import Testing

struct SpotlightCaffeinateCLICommandTests {
    @Test(arguments: startCases)
    func parseStartCommands(_ testCase: CLIParseCase) throws {
        #expect(try SpotlightCaffeinateCLIParser.parse(arguments: testCase.arguments) == testCase.expected)
    }

    @Test(arguments: invalidCases)
    func invalidCommandsThrow(_ testCase: CLIInvalidCase) {
        #expect(throws: CLIParseError.self) {
            try SpotlightCaffeinateCLIParser.parse(arguments: testCase.arguments)
        }
    }
}

struct CLIParseCase: Sendable {
    let arguments: [String]
    let expected: SpotlightCaffeinateCLICommand
}

struct CLIInvalidCase: Sendable {
    let arguments: [String]
}

let startCases: [CLIParseCase] = [
    CLIParseCase(
        arguments: ["start", "25", "--mode", "system"],
        expected: .start(minutes: 25, powerMode: .system, presetName: nil)
    ),
    CLIParseCase(
        arguments: ["start", "--preset", "Deep Work"],
        expected: .start(minutes: nil, powerMode: nil, presetName: "Deep Work")
    ),
    CLIParseCase(
        arguments: ["extend", "15"],
        expected: .extend(minutes: 15, presetName: nil)
    ),
    CLIParseCase(
        arguments: ["history", "--limit", "5", "--json"],
        expected: .history(limit: 5, json: true)
    ),
    CLIParseCase(
        arguments: ["status", "--json"],
        expected: .status(json: true)
    ),
    CLIParseCase(
        arguments: ["presets", "list"],
        expected: .presetsList(json: false)
    )
]

let invalidCases: [CLIInvalidCase] = [
    CLIInvalidCase(arguments: ["start", "15", "--preset", "Deep Work"]),
    CLIInvalidCase(arguments: ["start", "15", "--mode", "turbo"]),
    CLIInvalidCase(arguments: ["extend"]),
    CLIInvalidCase(arguments: ["history", "--limit", "0"]),
    CLIInvalidCase(arguments: ["presets"])
]
