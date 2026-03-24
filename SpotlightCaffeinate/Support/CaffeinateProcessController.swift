import Foundation
import IOKit.pwr_mgt

protocol CaffeinateProcessControlling: Sendable {
    func launch(arguments: [String]) throws -> Int32
    func terminate(pid: Int32) throws
    func isRunning(pid: Int32) -> Bool
}

final class SystemCaffeinateProcessController: @unchecked Sendable, CaffeinateProcessControlling {
    private struct AssertionRequest {
        let types: [CFString]
        let declaresUserActivity: Bool
    }

    private let stateLock = NSLock()
    private var nextHandleID: Int32 = 1
    private var activeAssertions: [Int32: [IOPMAssertionID]] = [:]

    func launch(arguments: [String]) throws -> Int32 {
        let request = try assertionRequest(for: arguments)
        var createdAssertions: [IOPMAssertionID] = []

        do {
            for assertionType in request.types {
                createdAssertions.append(try createAssertion(type: assertionType))
            }

            if request.declaresUserActivity {
                createdAssertions.append(try declareUserActivity())
            }
        } catch {
            releaseAssertions(createdAssertions)
            throw error
        }

        stateLock.lock()
        let handleID = nextHandleID
        nextHandleID += 1
        activeAssertions[handleID] = createdAssertions
        stateLock.unlock()

        return handleID
    }

    func terminate(pid: Int32) throws {
        stateLock.lock()
        let assertions = activeAssertions.removeValue(forKey: pid) ?? []
        stateLock.unlock()

        releaseAssertions(assertions)
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

        return AssertionRequest(types: types, declaresUserActivity: declaresUserActivity)
    }

    private func createAssertion(type: CFString) throws -> IOPMAssertionID {
        var assertionID = IOPMAssertionID(0)
        let result = IOPMAssertionCreateWithName(
            type,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "Spotlight Caffeinate session" as CFString,
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
