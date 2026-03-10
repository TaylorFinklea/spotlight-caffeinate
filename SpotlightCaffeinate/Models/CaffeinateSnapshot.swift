import Foundation

struct CaffeinateSnapshot: Codable, Equatable, Sendable {
    enum State: String, Codable, Sendable {
        case inactive
        case active
    }

    var state: State
    var pid: Int32?
    var startedAt: Date?
    var endsAt: Date?
    var minutesRequested: Int?

    static let inactive = CaffeinateSnapshot(
        state: .inactive,
        pid: nil,
        startedAt: nil,
        endsAt: nil,
        minutesRequested: nil
    )

    var isRunning: Bool {
        state == .active && remainingSeconds > 0
    }

    var remainingSeconds: Int {
        guard let endsAt else {
            return 0
        }

        return max(0, Int(endsAt.timeIntervalSinceNow.rounded(.down)))
    }

    var remainingText: String {
        let totalSeconds = remainingSeconds

        guard totalSeconds > 0 else {
            return "0s"
        }

        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        }

        if minutes > 0 {
            return seconds > 0 ? "\(minutes)m \(seconds)s" : "\(minutes)m"
        }

        return "\(seconds)s"
    }

    var statusLine: String {
        if isRunning {
            return "Running, \(remainingText) left"
        }

        return "Not running"
    }

    var spokenStatus: String {
        if isRunning {
            return "Caffeinate is running with \(remainingText) remaining."
        }

        return "Caffeinate is not running."
    }

    var menuBarTitle: String {
        isRunning ? remainingText : "Idle"
    }

    var menuBarSymbolName: String {
        isRunning ? "cup.and.saucer.fill" : "cup.and.saucer"
    }
}
