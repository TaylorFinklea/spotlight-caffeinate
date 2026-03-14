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

    func isRunning(at now: Date) -> Bool {
        state == .active && remainingSeconds(at: now) > 0
    }

    var isRunning: Bool {
        isRunning(at: .now)
    }

    var totalDuration: TimeInterval? {
        guard let startedAt, let endsAt, endsAt > startedAt else {
            return nil
        }

        return endsAt.timeIntervalSince(startedAt)
    }

    func remainingSeconds(at now: Date) -> Int {
        guard let endsAt else {
            return 0
        }

        return max(0, Int(endsAt.timeIntervalSince(now).rounded(.down)))
    }

    var remainingSeconds: Int {
        remainingSeconds(at: .now)
    }

    func remainingFraction(at now: Date) -> Double {
        guard state == .active else {
            return 0
        }

        guard let endsAt else {
            return 1
        }

        let remaining = endsAt.timeIntervalSince(now)
        guard remaining > 0 else {
            return 0
        }

        guard let totalDuration, totalDuration > 0 else {
            return 1
        }

        return min(max(remaining / totalDuration, 0), 1)
    }

    var remainingFraction: Double {
        remainingFraction(at: .now)
    }

    func remainingText(at now: Date) -> String {
        let totalSeconds = remainingSeconds(at: now)

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

    var remainingText: String {
        remainingText(at: .now)
    }

    func statusLine(at now: Date) -> String {
        if isRunning(at: now) {
            return "Running, \(remainingText(at: now)) left"
        }

        return "Not running"
    }

    var statusLine: String {
        statusLine(at: .now)
    }

    func spokenStatus(at now: Date) -> String {
        if isRunning(at: now) {
            return "Caffeinate is running with \(remainingText(at: now)) remaining."
        }

        return "Caffeinate is not running."
    }

    var spokenStatus: String {
        spokenStatus(at: .now)
    }

    func menuBarTitle(at now: Date) -> String {
        isRunning(at: now) ? remainingText(at: now) : "Idle"
    }

    var menuBarTitle: String {
        menuBarTitle(at: .now)
    }
}
