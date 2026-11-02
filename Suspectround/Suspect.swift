import Foundation

/// A named food on the shelf. Pick chooses one Suspect and the round fold
/// writes a SuspectMark for it. The suspect is not a calorie row.
struct Suspect: Codable, Sendable, Equatable, Identifiable {
    var id: UUID
    var name: String
}
