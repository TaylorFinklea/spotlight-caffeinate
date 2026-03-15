import Darwin
import Foundation

protocol CaffeinateProcessControlling: Sendable {
    func launch(arguments: [String]) throws -> Int32
    func terminate(pid: Int32) throws
    func isRunning(pid: Int32) -> Bool
}

struct SystemCaffeinateProcessController: CaffeinateProcessControlling {
    func launch(arguments: [String]) throws -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
        process.arguments = arguments
        try process.run()
        return process.processIdentifier
    }

    func terminate(pid: Int32) throws {
        guard isRunning(pid: pid) else {
            return
        }

        if kill(pid, SIGTERM) != 0, errno != ESRCH {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
        }
    }

    func isRunning(pid: Int32) -> Bool {
        kill(pid, 0) == 0 || errno == EPERM
    }
}
