import Foundation

enum PulseThreshold: String, Codable, CaseIterable, Equatable, Identifiable, Sendable {
    case off
    case seconds30
    case minute1
    case minutes5

    static let `default`: PulseThreshold = .minute1

    var id: String { rawValue }

    var title: String {
        switch self {
        case .off:
            return "Off"
        case .seconds30:
            return "30 sec"
        case .minute1:
            return "1 min"
        case .minutes5:
            return "5 min"
        }
    }

    var seconds: TimeInterval? {
        switch self {
        case .off:
            return nil
        case .seconds30:
            return 30
        case .minute1:
            return 60
        case .minutes5:
            return 300
        }
    }
}
