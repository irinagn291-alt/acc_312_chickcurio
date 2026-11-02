import Foundation

/// Simulator demo. One busted round, one cleared round, then a hunting round
/// with earlier clean days and today left unmarked so mark-the-day is legal.
extension Chart {
    static func demo(today: Int, calendar: Calendar = DayKey.stable) -> Chart {
        var chart = Chart.fresh()
        chart.blank = nil
        chart.onboardingComplete = true
        let regions = ["Head", "Gut", "Skin", "Joints"]
        chart.islands = regions.map { Island(id: UUID(), name: $0) }
        let names = ["Oat milk", "Wheat bread", "Almond butter", "Soy yogurt"]
        var outcome = RoundApply(chart: chart, refusal: nil)
        if let bustDay = DayKey.adding(days: -30, to: today, calendar: calendar) {
            outcome = playBusted(
                name: names[1],
                dayKey: bustDay,
                islandID: outcome.chart.islands.first?.id,
                calendar: calendar,
                on: outcome.chart
            )
        }
        if let start = DayKey.adding(days: -20, to: today, calendar: calendar) {
            outcome = playCleared(name: names[0], start: start, calendar: calendar, on: outcome.chart)
        }
        if let huntStart = DayKey.adding(days: -3, to: today, calendar: calendar) {
            outcome = playHunt(
                name: names[2],
                start: huntStart,
                cleanDays: 3,
                calendar: calendar,
                on: outcome.chart
            )
        }
        _ = outcome.chart.ensureBook(named: names[3])
        outcome.chart.onboardingComplete = true
        return outcome.chart
    }

    private static func playCleared(
        name: String,
        start: Int,
        calendar: Calendar,
        on chart: Chart
    ) -> RoundApply {
        var step = RoundFold.pick(name: name, dayKey: start, on: chart)
        var cursor = start
        for _ in 0..<RoundFold.clearSpan {
            step = RoundFold.markClean(dayKey: cursor, on: step.chart)
            if let next = DayKey.adding(days: 1, to: cursor, calendar: calendar) {
                cursor = next
            }
        }
        return step
    }

    private static func playBusted(
        name: String,
        dayKey: Int,
        islandID: UUID?,
        calendar: Calendar,
        on chart: Chart
    ) -> RoundApply {
        var step = RoundFold.pick(name: name, dayKey: dayKey, on: chart)
        step = RoundFold.markFlare(dayKey: dayKey, islandID: islandID, on: step.chart)
        let rotateDay = DayKey.adding(days: 1, to: dayKey, calendar: calendar) ?? dayKey
        step = RoundFold.rotate(dayKey: rotateDay, on: step.chart)
        return step
    }

    private static func playHunt(
        name: String,
        start: Int,
        cleanDays: Int,
        calendar: Calendar,
        on chart: Chart
    ) -> RoundApply {
        var step = RoundFold.pick(name: name, dayKey: start, on: chart)
        var cursor = start
        for _ in 0..<cleanDays {
            step = RoundFold.markClean(dayKey: cursor, on: step.chart)
            if let next = DayKey.adding(days: 1, to: cursor, calendar: calendar) {
                cursor = next
            }
        }
        return step
    }
}
