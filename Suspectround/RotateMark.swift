import Foundation

/// The rotate after a bust. Clears the live SuspectMark and folds the round
/// to Idle so the next Pick can start.
struct RotateMark: Codable, Sendable, Equatable, Identifiable {
    var id: UUID
    var dayKey: Int
    var productName: String
}
