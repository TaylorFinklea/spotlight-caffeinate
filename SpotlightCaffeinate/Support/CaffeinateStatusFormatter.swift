import Foundation

struct CaffeinateStatusFormatter {
    static func renderStatus(
        _ snapshot: CaffeinateSnapshot,
        now: Date,
        formatTimestamp: (Date) -> String
    ) -> String {
        let startedText = snapshot.startedAt.map(formatTimestamp) ?? "-"
        let endingText = snapshot.endsAt.map(formatTimestamp) ?? "-"
        let pidText = snapshot.pid.map(String.init) ?? "-"

        return """
        State: \(snapshot.isRunning(at: now) ? "running" : "idle")
        Remaining: \(snapshot.remainingText(at: now))
        Started: \(startedText)
        Ending: \(endingText)
        PID: \(pidText)
        """
    }

    static func renderWatchScreen(
        _ snapshot: CaffeinateSnapshot,
        now: Date,
        formatTimestamp: (Date) -> String,
        includeClearScreen: Bool = true
    ) -> String {
        let title = "Spotlight Caffeinate CLI"
        let divider = String(repeating: "=", count: title.count)
        let clear = includeClearScreen ? "\u{001B}[2J\u{001B}[H" : ""

        return """
        \(clear)\(title)
        \(divider)
        \(renderStatus(snapshot, now: now, formatTimestamp: formatTimestamp))

        Press Ctrl-C to stop watching.
        """
    }
}
