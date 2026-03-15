import Foundation

struct CaffeinateCLIJSONFormatter {
    static func renderStatus(_ snapshot: CaffeinateSnapshot, now: Date) throws -> String {
        try encode(
            StatusPayload(
                state: snapshot.isRunning(at: now) ? "running" : "idle",
                isRunning: snapshot.isRunning(at: now),
                remainingSeconds: snapshot.remainingSeconds(at: now),
                remainingText: snapshot.remainingText(at: now),
                startedAt: snapshot.startedAt,
                endsAt: snapshot.endsAt,
                minutesRequested: snapshot.minutesRequested,
                powerMode: snapshot.powerMode ?? (snapshot.state == .active ? .full : nil),
                presetID: snapshot.presetID,
                presetName: snapshot.presetName,
                source: snapshot.source,
                pid: snapshot.pid
            )
        )
    }

    static func renderHistory(_ entries: [RecentSessionEntry]) throws -> String {
        try encode(entries)
    }

    static func renderPresets(_ presets: [CaffeinatePreset]) throws -> String {
        try encode(presets)
    }

    private static func encode<T: Encodable>(_ value: T) throws -> String {
        let data = try encoder.encode(value)
        guard let string = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "CaffeinateCLIJSONFormatter", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not encode JSON output."])
        }

        return string
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}

private struct StatusPayload: Encodable {
    let state: String
    let isRunning: Bool
    let remainingSeconds: Int
    let remainingText: String
    let startedAt: Date?
    let endsAt: Date?
    let minutesRequested: Int?
    let powerMode: PowerMode?
    let presetID: UUID?
    let presetName: String?
    let source: CaffeinateSessionSource?
    let pid: Int32?
}
