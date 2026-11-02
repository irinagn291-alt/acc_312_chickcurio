import Foundation

/// Calendar day folded by the round. Each mark lands on one YYYYMMDD integer
/// taken from `Calendar.startOfDay`, so the elimination round is a fold over
/// day keys rather than timestamps.
enum DayKey {
    static func make(from date: Date, calendar: Calendar = .current) -> Int {
        let start = calendar.startOfDay(for: date)
        let parts = calendar.dateComponents([.year, .month, .day], from: start)
        let year = parts.year ?? 0
        let month = parts.month ?? 0
        let day = parts.day ?? 0
        return year * 10_000 + month * 100 + day
    }

    static func date(from key: Int, calendar: Calendar = .current) -> Date? {
        guard key > 0 else { return nil }
        var parts = DateComponents()
        parts.year = key / 10_000
        parts.month = (key / 100) % 100
        parts.day = key % 100
        guard let date = calendar.date(from: parts) else { return nil }
        return calendar.startOfDay(for: date)
    }

    static func adding(days: Int, to key: Int, calendar: Calendar = .current) -> Int? {
        guard let date = date(from: key, calendar: calendar),
              let shifted = calendar.date(byAdding: .day, value: days, to: date) else {
            return nil
        }
        return make(from: shifted, calendar: calendar)
    }

    static func isPlausible(_ key: Int) -> Bool {
        guard let date = date(from: key, calendar: Self.stable) else { return false }
        return make(from: date, calendar: Self.stable) == key
    }

    static var stable: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        if let zone = TimeZone(secondsFromGMT: 0) {
            calendar.timeZone = zone
        }
        return calendar
    }
}
