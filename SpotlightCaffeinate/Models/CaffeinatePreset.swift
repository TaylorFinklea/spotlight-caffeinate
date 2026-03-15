import Foundation

struct CaffeinatePreset: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var minutes: Int
    var powerMode: PowerMode
    var isPinned: Bool
    var sortOrder: Int
    var createdAt: Date
    var updatedAt: Date

    var durationLabel: String {
        "\(minutes)m"
    }

    static func defaultPresets(referenceDate: Date) -> [CaffeinatePreset] {
        [5, 15, 30, 60].enumerated().map { index, minutes in
            CaffeinatePreset(
                id: UUID(),
                name: "\(minutes)m",
                minutes: minutes,
                powerMode: .full,
                isPinned: true,
                sortOrder: index,
                createdAt: referenceDate,
                updatedAt: referenceDate
            )
        }
    }
}
