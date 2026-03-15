import Foundation

enum CaffeinateSessionSource: String, Codable, CaseIterable, Equatable, Sendable {
    case app
    case spotlight
    case cli

    var title: String {
        rawValue.capitalized
    }
}
