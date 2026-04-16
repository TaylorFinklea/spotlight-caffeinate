import Foundation
import IOKit.pwr_mgt
import Darwin

struct CaffeinateLaunchResult: Sendable {
    let pid: Int32
    let assertionIDs: [UInt32]?
}

protocol CaffeinateProcessControlling: Sendable {
    func launch(arguments: [String]) throws -> CaffeinateLaunchResult
    func terminate(pid: Int32) throws
    func terminate(assertionIDs: [UInt32]) throws
    func isRunning(pid: Int32) -> Bool
}

extension CaffeinateProcessControlling {
    func terminate(assertionIDs: [UInt32]) throws {
        for assertionID in assertionIDs {
            try terminate(pid: Int32(assertionID))
        }
    }
}

final class SubprocessCaffeinateProcessController: CaffeinateProcessControlling {
    private static let executableURL = URL(filePath: "/usr/bin/caffeinate")
    private static let executableName = "caffeinate"
    private static let processPathBufferSize = Int(MAXPATHLEN) * 4

    func launch(arguments: [String]) throws -> CaffeinateLaunchResult {
        let process = Process()
        process.executableURL = Self.executableURL
        process.arguments = arguments
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            throw NSError(
                domain: NSPOSIXErrorDomain,
                code: Int(EIO),
                userInfo: [NSLocalizedDescriptionKey: "Failed to launch /usr/bin/caffeinate: \(error.localizedDescription)"]
            )
        }

        return CaffeinateLaunchResult(
            pid: process.processIdentifier,
            assertionIDs: nil
        )
    }

    func terminate(pid: Int32) throws {
        guard isManagedCaffeinateProcess(pid: pid) else {
            return
        }

        if kill(pid, SIGTERM) == 0 || errno == ESRCH {
            return
        }

        let errorCode = errno
        throw NSError(
            domain: NSPOSIXErrorDomain,
            code: Int(errorCode),
            userInfo: [NSLocalizedDescriptionKey: String(cString: strerror(errorCode))]
        )
    }

    func isRunning(pid: Int32) -> Bool {
        guard isManagedCaffeinateProcess(pid: pid) else {
            return false
        }
        return true
    }

    private func isManagedCaffeinateProcess(pid: Int32) -> Bool {
        guard pid > 0 else {
            return false
        }

        if kill(pid, 0) != 0, errno != EPERM {
            return false
        }

        var buffer = [CChar](repeating: 0, count: Self.processPathBufferSize)
        let resolvedLength = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        guard resolvedLength > 0 else {
            return false
        }

        let bytes = buffer.prefix(Int(resolvedLength)).map(UInt8.init(bitPattern:))
        guard let processPath = String(bytes: bytes, encoding: .utf8) else {
            return false
        }
        return URL(fileURLWithPath: processPath).lastPathComponent == Self.executableName
    }
}

final class SystemCaffeinateProcessController: @unchecked Sendable, CaffeinateProcessControlling {
    private struct AssertionRequest {
        let types: [CFString]
        let declaresUserActivity: Bool
        let timeoutSeconds: CFTimeInterval
    }

    private let stateLock = NSLock()
    private var activeAssertions: [Int32: [IOPMAssertionID]] = [:]

    func launch(arguments: [String]) throws -> CaffeinateLaunchResult {
        let request = try assertionRequest(for: arguments)
        var createdAssertions: [IOPMAssertionID] = []

        do {
            for assertionType in request.types {
                createdAssertions.append(
                    try createAssertion(
                        type: assertionType,
                        timeoutSeconds: request.timeoutSeconds
                    )
                )
            }

            if request.declaresUserActivity {
                createdAssertions.append(try declareUserActivity())
            }
        } catch {
            releaseAssertions(createdAssertions)
            throw error
        }

        stateLock.lock()
        let handleID = Int32(createdAssertions.first ?? 0)
        activeAssertions[handleID] = createdAssertions
        stateLock.unlock()

        return CaffeinateLaunchResult(
            pid: handleID,
            assertionIDs: createdAssertions.map { assertion in
                UInt32(assertion)
            }
        )
    }

    func terminate(pid: Int32) throws {
        stateLock.lock()
        let assertions = activeAssertions.removeValue(forKey: pid) ?? []
        stateLock.unlock()

        if assertions.isEmpty {
            _ = IOPMAssertionRelease(IOPMAssertionID(pid))
            return
        }

        releaseAssertions(assertions)
    }

    func terminate(assertionIDs: [UInt32]) throws {
        releaseAssertions(assertionIDs.map { assertionID in
            IOPMAssertionID(assertionID)
        })
    }

    func isRunning(pid: Int32) -> Bool {
        stateLock.lock()
        let isActive = activeAssertions[pid] != nil
        stateLock.unlock()
        return isActive
    }

    private func assertionRequest(for arguments: [String]) throws -> AssertionRequest {
        let flags = Set(arguments.filter { $0.hasPrefix("-") })
        let keepsDisplayAwake = flags.contains("-d")
        let keepsSystemAwake = flags.contains("-i") || flags.contains("-s")
        let declaresUserActivity = flags.contains("-u")
        let timeoutSeconds = assertionTimeout(from: arguments)

        var types: [CFString] = []

        if keepsDisplayAwake {
            types.append(kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString)
        }

        if keepsSystemAwake {
            types.append(kIOPMAssertionTypePreventUserIdleSystemSleep as CFString)
        }

        guard !types.isEmpty || declaresUserActivity else {
            throw NSError(
                domain: NSPOSIXErrorDomain,
                code: Int(EINVAL),
                userInfo: [NSLocalizedDescriptionKey: "No supported keep-awake assertions were requested."]
            )
        }

        return AssertionRequest(
            types: types,
            declaresUserActivity: declaresUserActivity,
            timeoutSeconds: timeoutSeconds
        )
    }

    private func createAssertion(type: CFString, timeoutSeconds: CFTimeInterval) throws -> IOPMAssertionID {
        var assertionID = IOPMAssertionID(0)
        let result = IOPMAssertionCreateWithDescription(
            type,
            "Spotlight Caffeinate session" as CFString,
            nil,
            nil,
            nil,
            timeoutSeconds,
            nil,
            &assertionID
        )

        guard result == kIOReturnSuccess else {
            throw NSError(
                domain: NSOSStatusErrorDomain,
                code: Int(result),
                userInfo: [NSLocalizedDescriptionKey: "Power assertion request failed with code \(result)."]
            )
        }

        return assertionID
    }

    private func assertionTimeout(from arguments: [String]) -> CFTimeInterval {
        guard let timeoutIndex = arguments.firstIndex(of: "-t"), arguments.indices.contains(timeoutIndex + 1) else {
            return 0
        }

        return CFTimeInterval(Int(arguments[timeoutIndex + 1]) ?? 0)
    }

    private func declareUserActivity() throws -> IOPMAssertionID {
        var assertionID = IOPMAssertionID(0)
        let result = IOPMAssertionDeclareUserActivity(
            "Spotlight Caffeinate session" as CFString,
            kIOPMUserActiveLocal,
            &assertionID
        )

        guard result == kIOReturnSuccess else {
            throw NSError(
                domain: NSOSStatusErrorDomain,
                code: Int(result),
                userInfo: [NSLocalizedDescriptionKey: "User activity assertion failed with code \(result)."]
            )
        }

        return assertionID
    }

    private func releaseAssertions(_ assertions: [IOPMAssertionID]) {
        for assertion in assertions {
            IOPMAssertionRelease(assertion)
        }
    }
}
