import Foundation

enum CaffeinateSessionSource: String, Codable, CaseIterable, Equatable, Sendable {
    case app
    case spotlight
    case cli
    case automation

    var title: String {
        switch self {
        case .automation:
            return "Automation"
        case .app, .spotlight, .cli:
            return rawValue.capitalized
        }
    }
}
