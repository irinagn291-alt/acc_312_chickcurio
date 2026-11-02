import Foundation

/// Empty-round marker. A chart with no session writes Blank instead of an
/// invented hunting phase.
struct Blank: Codable, Sendable, Equatable, Identifiable {
    var id: UUID
}
