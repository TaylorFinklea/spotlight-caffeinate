import Foundation

enum GlyphStyle: String, Codable, CaseIterable, Equatable, Identifiable, Sendable {
    case boltFill
    case ring
    case text

    static let `default`: GlyphStyle = .boltFill

    var id: String { rawValue }

    var title: String {
        switch self {
        case .boltFill:
            return "Bolt"
        case .ring:
            return "Ring"
        case .text:
            return "Bolt + Time"
        }
    }

    var detailText: String {
        switch self {
        case .boltFill:
            return "Bolt drains from top to bottom as the session elapses."
        case .ring:
            return "Circle progress arc shrinks around a static bolt."
        case .text:
            return "Compact remaining-time text next to a small bolt."
        }
    }
}
