import Foundation

/// The pick written onto one product. While this mark is set, the round is
/// Hunting. Rotate clears it and folds the round back to Idle.
struct SuspectMark: Codable, Sendable, Equatable, Identifiable {
    var id: UUID
    var bookID: UUID
    var name: String
    var dayKey: Int
}
