import Foundation

/// A symptom day on the hunting round. Writing this mark also writes a
/// BustMark and folds Hunting to Busted.
struct FlareMark: Codable, Sendable, Equatable, Identifiable {
    var id: UUID
    var dayKey: Int
    var islandID: UUID?
}
