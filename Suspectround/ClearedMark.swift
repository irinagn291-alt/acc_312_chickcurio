import Foundation

/// Written when seven consecutive clean marks close a hunting round.
/// A cleared round lifts the ban on the last busted suspect.
struct ClearedMark: Codable, Sendable, Equatable, Identifiable {
    var id: UUID
    var dayKey: Int
    var productName: String
}
