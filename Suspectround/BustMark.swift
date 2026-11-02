import Foundation

/// The bust sealed when a flare lands. Keeps the product name after Rotate
/// clears the live SuspectMark, so the rotation ledger still names who busted.
struct BustMark: Codable, Sendable, Equatable, Identifiable {
    var id: UUID
    var dayKey: Int
    var productName: String
}
