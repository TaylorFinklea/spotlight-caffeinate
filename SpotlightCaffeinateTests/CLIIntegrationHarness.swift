import Foundation

/// Spawns the built `spotlight-caffeinate-cli` binary with an isolated
/// storage root and returns completed or still-running processes.
///
/// The binary is located relative to the test bundle: Xcode places
/// `SpotlightCaffeinateTests.xctest` and `spotlight-caffeinate-cli`
/// in the same `BUILT_PRODUCTS_DIR`. The test target declares a
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
        let testBundleURL = Bundle(for: CLIBundleAnchor.self).bundleURL
        let productsDir = testBundleURL.deletingLastPathComponent()
        let binaryURL = productsDir.appending(path: "spotlight-caffeinate-cli")

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
    ///
    /// Pipe drainage uses `readabilityHandler` instead of `readToEnd()`
    /// because the CLI may spawn `/usr/bin/caffeinate` which inherits
    /// the pipe's write-end FD and prevents EOF from arriving after
    /// the CLI itself exits.
    func run(_ arguments: [String], timeout: Duration = .seconds(10)) async throws -> CLIResult {
        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()
        process.executableURL = binaryURL
        process.arguments = arguments
        process.standardOutput = stdout
        process.standardError = stderr
        process.environment = processEnvironment()

        let stdoutCollector = PipeCollector()
        let stderrCollector = PipeCollector()
        stdoutCollector.install(on: stdout.fileHandleForReading)
        stderrCollector.install(on: stderr.fileHandleForReading)

        try process.run()

        let timeoutTask = Task {
            try? await Task.sleep(for: timeout)
            if process.isRunning {
                process.terminate()
            }
        }
        defer { timeoutTask.cancel() }

        await Task.detached { process.waitUntilExit() }.value

        // Let any trailing writes land before we tear down the handlers.
        try? await Task.sleep(for: .milliseconds(50))
        stdout.fileHandleForReading.readabilityHandler = nil
        stderr.fileHandleForReading.readabilityHandler = nil
        try? stdout.fileHandleForReading.close()
        try? stderr.fileHandleForReading.close()

        return CLIResult(
            exitCode: process.terminationStatus,
            stdout: String(decoding: stdoutCollector.finalize(), as: UTF8.self),
            stderr: String(decoding: stderrCollector.finalize(), as: UTF8.self)
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

    /// Synchronous filesystem cleanup. Suitable for `defer` blocks where
    /// launching a fire-and-forget `Task { await cleanup() }` would leak
    /// file descriptors across parallel/serialized test runs. Individual
    /// tests are expected to call `stop` explicitly before returning when
    /// they started a session.
    func cleanupStorage() {
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
    case missingBinary(String)

    var description: String {
        switch self {
        case .missingBinary(let path):
            return "spotlight-caffeinate-cli binary not found at \(path). The test target must depend on the CLI target."
        }
    }
}

/// Anchor class used only to resolve the test bundle URL via `Bundle(for:)`.
/// Swift Testing `@Suite` structs do not have a runtime class, so an
/// explicit anchor is needed to bridge to `Bundle(for:)`.
private final class CLIBundleAnchor {}

/// Accumulates data from a `FileHandle` via `readabilityHandler`.
/// Used to drain CLI subprocess pipes during process lifetime so
/// blocking reads don't wait on descriptors inherited by grandchildren
/// like `/usr/bin/caffeinate`.
private final class PipeCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var buffer = Data()

    func install(on handle: FileHandle) {
        handle.readabilityHandler = { [weak self] pipe in
            let chunk = pipe.availableData
            if chunk.isEmpty { return }
            self?.lock.lock()
            self?.buffer.append(chunk)
            self?.lock.unlock()
        }
    }

    func finalize() -> Data {
        lock.lock()
        defer { lock.unlock() }
        return buffer
    }
}
