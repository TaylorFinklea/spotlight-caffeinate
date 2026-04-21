import Foundation

/// Spawns the built `spotlight-caffeinate-cli` binary with an isolated
/// storage root and returns completed or still-running processes.
///
/// The binary path is resolved from the `BUILT_PRODUCTS_DIR` environment
/// variable that Xcode sets at test time. The test target declares a
/// build-order dependency on `SpotlightCaffeinateCLI` in `project.yml`
/// so the binary is guaranteed to exist before tests run.
///
/// Each invocation runs with `SPOTLIGHT_CAFFEINATE_STORAGE_ROOT` set to
/// the harness's `storageRoot` so reads/writes go to a hermetic temp
/// directory instead of the real App Group or user Application Support.
struct CLIRunner {
    let binaryURL: URL
    let storageRoot: URL

    static func make() throws -> CLIRunner {
        guard
            let builtProductsDir = ProcessInfo.processInfo.environment["BUILT_PRODUCTS_DIR"]
                .flatMap({ $0.isEmpty ? nil : $0 })
        else {
            throw CLIRunnerError.missingBuiltProductsDir
        }

        let binaryURL = URL(fileURLWithPath: builtProductsDir, isDirectory: true)
            .appending(path: "spotlight-caffeinate-cli")

        guard FileManager.default.isExecutableFile(atPath: binaryURL.path) else {
            throw CLIRunnerError.missingBinary(binaryURL.path)
        }

        let storageRoot = FileManager.default.temporaryDirectory
            .appending(path: "SpotlightCaffeinateCLIIntegration-\(UUID().uuidString)",
                       directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: storageRoot, withIntermediateDirectories: true)

        return CLIRunner(binaryURL: binaryURL, storageRoot: storageRoot)
    }

    /// Runs the CLI with the given arguments and waits for it to exit.
    /// Times out by sending SIGTERM if the process exceeds `timeout`.
    func run(_ arguments: [String], timeout: Duration = .seconds(10)) async throws -> CLIResult {
        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()
        process.executableURL = binaryURL
        process.arguments = arguments
        process.standardOutput = stdout
        process.standardError = stderr
        process.environment = processEnvironment()

        try process.run()

        let timeoutTask = Task {
            try? await Task.sleep(for: timeout)
            if process.isRunning {
                process.terminate()
            }
        }
        defer { timeoutTask.cancel() }

        await Task.detached { process.waitUntilExit() }.value

        let stdoutData = try stdout.fileHandleForReading.readToEnd() ?? Data()
        let stderrData = try stderr.fileHandleForReading.readToEnd() ?? Data()

        return CLIResult(
            exitCode: process.terminationStatus,
            stdout: String(decoding: stdoutData, as: UTF8.self),
            stderr: String(decoding: stderrData, as: UTF8.self)
        )
    }

    /// Spawns the CLI without waiting. Callers drive it via `RunningProcess`
    /// and must call `terminate()` + `waitUntilExit()` before the test ends.
    func spawn(_ arguments: [String]) throws -> RunningProcess {
        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()
        process.executableURL = binaryURL
        process.arguments = arguments
        process.standardOutput = stdout
        process.standardError = stderr
        process.environment = processEnvironment()

        try process.run()

        return RunningProcess(process: process, stdout: stdout, stderr: stderr)
    }

    /// Writes a single preset to the hermetic storage directory so tests
    /// that reference presets by name can execute without seeding them
    /// through the CLI first.
    func seedPreset(name: String, minutes: Int, powerMode: String = "full", pinned: Bool = false) throws {
        let appDirectory = storageRoot.appending(path: "SpotlightCaffeinate", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true)

        let id = UUID().uuidString.lowercased()
        let iso = ISO8601DateFormatter().string(from: Date(timeIntervalSinceReferenceDate: 0))
        let preset: [String: Any] = [
            "id": id,
            "name": name,
            "minutes": minutes,
            "powerMode": powerMode,
            "isPinned": pinned,
            "sortOrder": 0,
            "createdAt": iso,
            "updatedAt": iso
        ]
        let payload = try JSONSerialization.data(
            withJSONObject: [preset],
            options: [.sortedKeys, .prettyPrinted]
        )
        try payload.write(to: appDirectory.appending(path: "presets.json"), options: .atomic)
    }

    /// Best-effort teardown: stops any lingering caffeinate session the CLI
    /// may have left running. Safe to call even when no session is active.
    func cleanup() async {
        _ = try? await run(["stop"], timeout: .seconds(5))
        try? FileManager.default.removeItem(at: storageRoot)
    }

    private func processEnvironment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        environment["SPOTLIGHT_CAFFEINATE_STORAGE_ROOT"] = storageRoot.path
        return environment
    }
}

struct CLIResult: Sendable {
    let exitCode: Int32
    let stdout: String
    let stderr: String
}

final class RunningProcess {
    let process: Process
    let stdout: Pipe
    let stderr: Pipe

    init(process: Process, stdout: Pipe, stderr: Pipe) {
        self.process = process
        self.stdout = stdout
        self.stderr = stderr
    }

    /// Reads the next newline-terminated line from stdout. Returns `nil`
    /// if the stream closes before a line is produced. Times out by
    /// returning `nil`; callers should treat timeout as a test failure.
    func readLine(timeout: Duration) async throws -> String? {
        let readerTask = Task.detached(priority: .userInitiated) { [stdout] () -> String? in
            let handle = stdout.fileHandleForReading
            var buffer = Data()
            while true {
                let chunk = handle.availableData
                if chunk.isEmpty { return nil } // EOF
                buffer.append(chunk)
                if let newlineIndex = buffer.firstIndex(of: 0x0A) {
                    let lineData = buffer.prefix(upTo: newlineIndex)
                    return String(decoding: lineData, as: UTF8.self)
                }
            }
        }

        let timeoutTask = Task {
            try? await Task.sleep(for: timeout)
            readerTask.cancel()
        }
        defer { timeoutTask.cancel() }

        return await readerTask.value
    }

    func terminate() {
        if process.isRunning {
            process.terminate()
        }
    }

    func waitUntilExit() async -> Int32 {
        await Task.detached { [process] in
            process.waitUntilExit()
            return process.terminationStatus
        }.value
    }
}

enum CLIRunnerError: Error, CustomStringConvertible {
    case missingBuiltProductsDir
    case missingBinary(String)

    var description: String {
        switch self {
        case .missingBuiltProductsDir:
            return "BUILT_PRODUCTS_DIR is not set. Run tests through xcodebuild or Xcode."
        case .missingBinary(let path):
            return "spotlight-caffeinate-cli binary not found at \(path). The test target must depend on the CLI target."
        }
    }
}
