import Foundation

/// A named intake on a day. This is the meal entry for the food-symptom
/// family. Tokens split on comma or newline. The overlap score is
/// matched/totalSymptoms and is not calories. The score never folds the round.
struct Intake: Codable, Sendable, Equatable, Identifiable {
    var id: UUID
    var dayKey: Int
    var name: String

    static func tokens(in meal: String) -> [String] {
        meal
            .split { character in
                character == "," || character == "\n" || character == "\r"
            }
            .map { piece in
                piece.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            }
            .filter { !$0.isEmpty }
    }
}

/// One symptom pulse paired with a meal. Lookback hours must stay inside 0...6
/// or the whole row drops. This is the symptom entry for the family invariant.
struct IntakeSymptom: Sendable, Equatable {
    var name: String
    var lookbackHours: Double
}

/// Family invariant. score = matched / totalSymptoms. Drop the row when
/// matched is under 2, when the lookback leaves 0...6 hours, or when there
/// is nothing to divide. The result is a ratio, never a calorie count.
enum IntakeOverlap {
    static func score(meal: String, symptoms: [IntakeSymptom]) -> Double? {
        let total = symptoms.count
        guard total > 0 else { return nil }
        guard symptoms.allSatisfy({ (0...6).contains($0.lookbackHours) }) else { return nil }
        let tokens = Set(Intake.tokens(in: meal))
        let matched = symptoms.reduce(into: 0) { count, symptom in
            let needle = symptom.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if !needle.isEmpty, tokens.contains(needle) {
                count += 1
            }
        }
        guard matched >= 2 else { return nil }
        return Double(matched) / Double(total)
    }
}
