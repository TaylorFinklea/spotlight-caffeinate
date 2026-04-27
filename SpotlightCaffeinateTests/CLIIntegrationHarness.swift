import Darwin
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
    /// Output is captured by redirecting the CLI's stdout/stderr to
    /// temp files instead of pipes. Pipes deadlock here when the CLI
    /// spawns `/usr/bin/caffeinate` and Foundation's `Process` does not
    /// fully release the parent's copy of the pipe write end after
    /// `run()`. Temp files have no EOF semantics, so the readers can
    /// run freely after the child exits.
    func run(_ arguments: [String], timeout: Duration = .seconds(10)) async throws -> CLIResult {
        let stdoutURL = Self.makeOutputTempFile()
        let stderrURL = Self.makeOutputTempFile()
        defer {
            try? FileManager.default.removeItem(at: stdoutURL)
            try? FileManager.default.removeItem(at: stderrURL)
        }

        let stdoutHandle = try FileHandle(forWritingTo: stdoutURL)
        let stderrHandle = try FileHandle(forWritingTo: stderrURL)
        defer {
            try? stdoutHandle.close()
            try? stderrHandle.close()
        }

        let process = Process()
        process.executableURL = binaryURL
        process.arguments = arguments
        process.standardOutput = stdoutHandle
        process.standardError = stderrHandle
        process.environment = processEnvironment()

        let timeoutTask = Task {
            try? await Task.sleep(for: timeout)
            if process.isRunning {
                process.terminate()
            }
        }
        defer { timeoutTask.cancel() }

        let exitCode: Int32 = try await withCheckedThrowingContinuation { continuation in
            let resumer = ContinuationResumer(continuation: continuation)
            process.terminationHandler = { task in
                resumer.resume(.success(task.terminationStatus))
            }
            do {
                try process.run()
            } catch {
                resumer.resume(.failure(error))
            }
        }

        let stdoutData = (try? Data(contentsOf: stdoutURL)) ?? Data()
        let stderrData = (try? Data(contentsOf: stderrURL)) ?? Data()

        return CLIResult(
            exitCode: exitCode,
            stdout: String(decoding: stdoutData, as: UTF8.self),
            stderr: String(decoding: stderrData, as: UTF8.self)
        )
    }

    private static func makeOutputTempFile() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "spotlight-caffeinate-cli-out-\(UUID().uuidString).log")
        FileManager.default.createFile(atPath: url.path, contents: nil)
        return url
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

        Self.markCloseOnExec(stdout)
        Self.markCloseOnExec(stderr)

        // Set the termination handler before `run()` so we cannot miss
        // a fast-exiting process. The handler bridges Foundation's
        // process-exit signal into a Task we can `await` reliably,
        // bypassing `Process.waitUntilExit()` which has been observed
        // to hang here even after the child has terminated.
        let (exitStream, exitContinuation) = AsyncStream<Int32>.makeStream(bufferingPolicy: .bufferingNewest(1))
        process.terminationHandler = { task in
            exitContinuation.yield(task.terminationStatus)
            exitContinuation.finish()
        }

        do {
            try process.run()
        } catch {
            exitContinuation.finish()
            throw error
        }

        let exitTask: Task<Int32, Never> = Task {
            var iterator = exitStream.makeAsyncIterator()
            return await iterator.next() ?? -1
        }

        // Drop the parent's copy of the write end so EOF on the read end
        // arrives when the child exits (see `run` for the longer note).
        try? stdout.fileHandleForWriting.close()
        try? stderr.fileHandleForWriting.close()

        return RunningProcess(process: process, stdout: stdout, stderr: stderr, exitTask: exitTask)
    }

    /// Marks both ends of `pipe` close-on-exec so the spawned CLI does not
    /// leak the test-side pipe descriptors into its own grandchildren
    /// (most notably `/usr/bin/caffeinate`). Without this, the grandchild
    /// keeps a copy of the pipe write end open past the CLI's exit and the
    /// test harness's next pipe read can hang waiting for EOF.
    ///
    /// Foundation promotes the pipe write end onto the child's fd 1/2
    /// using `posix_spawn_file_actions_adddup2` before exec, and dup2
    /// clears `FD_CLOEXEC` on the destination, so the CLI still gets a
    /// usable stdout/stderr. The original parent-side fds remain
    /// inherited at their original numbers until exec; with
    /// `FD_CLOEXEC` set, exec closes them and they never reach grandchildren.
    private static func markCloseOnExec(_ pipe: Pipe) {
        for fd in [pipe.fileHandleForReading.fileDescriptor,
                   pipe.fileHandleForWriting.fileDescriptor] {
            let flags = fcntl(fd, F_GETFD)
            if flags >= 0 {
                _ = fcntl(fd, F_SETFD, flags | FD_CLOEXEC)
            }
        }
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
    private let exitTask: Task<Int32, Never>

    init(process: Process, stdout: Pipe, stderr: Pipe, exitTask: Task<Int32, Never>) {
        self.process = process
        self.stdout = stdout
        self.stderr = stderr
        self.exitTask = exitTask
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
        await exitTask.value
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

/// Single-shot wrapper around `CheckedContinuation` so the termination
/// handler and the synchronous `process.run()` failure path can both
/// resolve the same continuation without risking a double resume.
private final class ContinuationResumer: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Int32, Error>?

    init(continuation: CheckedContinuation<Int32, Error>) {
        self.continuation = continuation
    }

    func resume(_ result: Result<Int32, Error>) {
        lock.lock()
        let pending = continuation
        continuation = nil
        lock.unlock()
        guard let pending else { return }
        switch result {
        case .success(let value): pending.resume(returning: value)
        case .failure(let error): pending.resume(throwing: error)
        }
    }
}

