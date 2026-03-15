import Foundation

enum PowerMode: String, Codable, CaseIterable, Equatable, Identifiable, Sendable {
    case display
    case system
    case full

    var id: String { rawValue }

    var title: String {
        switch self {
        case .display:
            return "Display"
        case .system:
            return "System"
        case .full:
            return "Full"
        }
    }

    var shortLabel: String {
        rawValue.capitalized
    }

    var intentDescription: String {
        rawValue
    }

    var detailText: String {
        switch self {
        case .display:
            return "Keeps the display awake."
        case .system:
            return "Keeps the system awake and active."
        case .full:
            return "Keeps both the display and system awake."
        }
    }

    var caffeinateFlags: [String] {
        switch self {
        case .display:
            return ["-d", "-u"]
        case .system:
            return ["-i", "-s", "-u"]
        case .full:
            return ["-d", "-i", "-s", "-u"]
        }
    }
}
