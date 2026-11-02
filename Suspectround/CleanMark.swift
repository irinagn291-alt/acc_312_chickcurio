import Foundation

/// A clean day on the open hunting round. Seven of these with no flare
/// between them fold Hunting to Cleared.
struct CleanMark: Codable, Sendable, Equatable, Identifiable {
    var id: UUID
    var dayKey: Int
}
