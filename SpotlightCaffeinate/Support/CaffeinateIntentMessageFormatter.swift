import Foundation

struct CaffeinateIntentMessageFormatter {
    static func startDialog(for snapshot: CaffeinateSnapshot, fallbackMinutes: Int) -> String {
        let minutes = snapshot.minutesRequested ?? fallbackMinutes
        var parts = ["Caffeinate started for \(minutes) minute\(minutes == 1 ? "" : "s")"]

        if let presetName = snapshot.presetName {
            parts.append("using \(presetName)")
        }

        if let automationRuleName = snapshot.automationRuleName {
            parts.append("from automation \(automationRuleName)")
        }

        parts.append("in \(snapshot.effectivePowerMode.intentDescription) mode")

        if let endingText = snapshot.endsAt?.formatted(date: .omitted, time: .shortened) {
            parts.append("and ends at \(endingText)")
        }

        return parts.joined(separator: " ") + "."
    }

    static func statusDialog(for snapshot: CaffeinateSnapshot, now: Date) -> String {
        guard snapshot.isRunning(at: now) else {
            return "Caffeinate is not running."
        }

        var parts = ["Caffeinate is running with \(snapshot.remainingText(at: now)) remaining"]

        if let presetName = snapshot.presetName {
            parts.append("for \(presetName)")
        }

        if let automationRuleName = snapshot.automationRuleName {
            parts.append("from automation \(automationRuleName)")
        }

        parts.append("in \(snapshot.effectivePowerMode.intentDescription) mode")

        if let endingText = snapshot.endsAt?.formatted(date: .omitted, time: .shortened) {
            parts.append("and ends at \(endingText)")
        }

        return parts.joined(separator: " ") + "."
    }

    static func extendDialog(for snapshot: CaffeinateSnapshot, addedMinutes: Int, now: Date) -> String {
        "Caffeinate extended by \(addedMinutes) minute\(addedMinutes == 1 ? "" : "s"). \(statusDialog(for: snapshot, now: now))"
    }

    static func restartUnavailableDialog() -> String {
        "No recent session is available to restart."
    }
}
