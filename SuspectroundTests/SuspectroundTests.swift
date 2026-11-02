import XCTest
@testable import Suspectround

final class SuspectroundTests: XCTestCase {
    private var directory: URL!
    private var suite: String!

    override func setUp() async throws {
        suite = "SuspectroundTests.\(UUID().uuidString)"
        directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent(suite, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
        try? FileManager.default.removeItem(at: directory)
    }

    func testIntakeOverlapDropsWeakAndOutOfWindowRows() {
        let meal = "Oat milk, Wheat bread\nAlmond butter"
        XCTAssertEqual(
            Intake.tokens(in: meal),
            ["oat milk", "wheat bread", "almond butter"]
        )
        let symptoms = [
            IntakeSymptom(name: "Oat milk", lookbackHours: 0),
            IntakeSymptom(name: "Wheat bread", lookbackHours: 6),
            IntakeSymptom(name: "Egg", lookbackHours: 2),
        ]
        let score = IntakeOverlap.score(meal: meal, symptoms: symptoms)
        // score = matched / totalSymptoms, and the row drops when matched is under 2.
        XCTAssertEqual(score, 2.0 / 3.0)
        XCTAssertNil(IntakeOverlap.score(meal: meal, symptoms: [
            IntakeSymptom(name: "Oat milk", lookbackHours: 1),
            IntakeSymptom(name: "Egg", lookbackHours: 1),
            IntakeSymptom(name: "Rice", lookbackHours: 1),
        ]))
        XCTAssertNil(IntakeOverlap.score(meal: "", symptoms: symptoms))
        XCTAssertNil(IntakeOverlap.score(meal: meal, symptoms: [
            IntakeSymptom(name: "Oat milk", lookbackHours: -0.1),
            IntakeSymptom(name: "Wheat bread", lookbackHours: 1),
        ]))
        XCTAssertNil(IntakeOverlap.score(meal: meal, symptoms: [
            IntakeSymptom(name: "Oat milk", lookbackHours: 6.1),
            IntakeSymptom(name: "Wheat bread", lookbackHours: 1),
        ]))
        XCTAssertNil(IntakeOverlap.score(meal: meal, symptoms: []))
    }

    func testOverlapScoreDoesNotBustTheRound() {
        let today = DayKey.make(from: Date(), calendar: DayKey.stable)
        var chart = Chart.fresh()
        let picked = RoundFold.pick(name: "Oat milk", dayKey: today, on: chart)
        chart = picked.chart
        let scored = RoundFold.applyingOverlapScore(1, to: chart)
        XCTAssertEqual(scored.phase, .hunting)
        XCTAssertNil(scored.sessions.last?.bust)
        XCTAssertEqual(scored.sessions.last?.suspect?.name, "Oat milk")
    }

    func testMarkTheDayEmptyPopulatedAndInvalid() {
        let today = DayKey.make(from: Date(), calendar: DayKey.stable)
        let empty = RoundFold.markClean(dayKey: today, on: Chart.fresh())
        XCTAssertEqual(empty.refusal, .markOnIdle)
        XCTAssertNotNil(empty.chart.blank)
        XCTAssertTrue(empty.chart.sessions.isEmpty)

        let picked = RoundFold.pick(name: "Almond butter", dayKey: today, on: Chart.fresh())
        XCTAssertNil(picked.refusal)
        XCTAssertEqual(picked.chart.phase, .hunting)
        let marked = RoundFold.markClean(dayKey: today, on: picked.chart)
        XCTAssertNil(marked.refusal)
        XCTAssertEqual(marked.chart.sessions.last?.cleans.map(\.dayKey), [today])
        XCTAssertEqual(marked.chart.cleanCount, 1)

        let duplicate = RoundFold.markClean(dayKey: today, on: marked.chart)
        XCTAssertEqual(duplicate.refusal, .duplicateDay)
        XCTAssertEqual(duplicate.chart.sessions.last?.cleans.count, 1)

        let nameless = RoundFold.pick(name: "   ", dayKey: today, on: Chart.fresh())
        XCTAssertEqual(nameless.refusal, .emptyName)
        let badDay = RoundFold.markClean(dayKey: 20261340, on: picked.chart)
        XCTAssertEqual(badDay.refusal, .invalidDay)
    }

    func testSuspectThenBustFold() {
        let calendar = DayKey.stable
        let today = DayKey.make(from: Date(), calendar: calendar)
        var chart = Chart.fresh()

        let idleMark = RoundFold.markClean(dayKey: today, on: chart)
        XCTAssertEqual(idleMark.refusal, .markOnIdle)

        chart = RoundFold.pick(name: "Wheat bread", dayKey: today, on: chart).chart
        let second = RoundFold.pick(name: "Soy yogurt", dayKey: today, on: chart)
        XCTAssertEqual(second.refusal, .secondPick)
        XCTAssertEqual(chart.phase, .hunting)

        chart = RoundFold.markFlare(dayKey: today, islandID: nil, on: chart).chart
        XCTAssertEqual(chart.phase, .busted)
        XCTAssertEqual(chart.sessions.last?.flares.count, 1)
        XCTAssertEqual(chart.sessions.last?.bust?.productName, "Wheat bread")
        let markWhileBusted = RoundFold.markClean(dayKey: today, on: chart)
        XCTAssertEqual(markWhileBusted.refusal, .markOnBusted)

        guard let rotateDay = DayKey.adding(days: 1, to: today, calendar: calendar) else {
            XCTFail("Missing rotate day")
            return
        }
        chart = RoundFold.rotate(dayKey: rotateDay, on: chart).chart
        XCTAssertEqual(chart.phase, .idle)
        XCTAssertNil(chart.sessions.last?.suspect)
        XCTAssertEqual(chart.rhumbs.map(\.mark.productName), ["Wheat bread"])
        XCTAssertEqual(RoundFold.markFlare(dayKey: rotateDay, islandID: nil, on: chart).refusal, .markOnIdle)

        let repeatBust = RoundFold.pick(name: "wheat bread", dayKey: rotateDay, on: chart)
        XCTAssertEqual(repeatBust.refusal, .repeatsLastBust)
        chart = RoundFold.pick(name: "Oat milk", dayKey: rotateDay, on: chart).chart
        var cursor = rotateDay
        for _ in 0..<RoundFold.clearSpan {
            let applied = RoundFold.markClean(dayKey: cursor, on: chart)
            XCTAssertNil(applied.refusal)
            chart = applied.chart
            if let next = DayKey.adding(days: 1, to: cursor, calendar: calendar) {
                cursor = next
            }
        }
        XCTAssertEqual(chart.phase, .cleared)
        XCTAssertEqual(chart.sessions.last?.cleans.count, 7)
        XCTAssertNotNil(chart.sessions.last?.cleared)
        XCTAssertNil(chart.bannedSuspectName)
        let afterClear = RoundFold.pick(name: "Wheat bread", dayKey: cursor, on: chart)
        XCTAssertNil(afterClear.refusal)
        XCTAssertEqual(afterClear.chart.phase, .hunting)
    }

    func testSixCleansStayHuntingAndSeventhClears() {
        let calendar = DayKey.stable
        var day = DayKey.make(from: Date(), calendar: calendar)
        var chart = RoundFold.pick(name: "Soy yogurt", dayKey: day, on: Chart.fresh()).chart
        for index in 0..<6 {
            chart = RoundFold.markClean(dayKey: day, on: chart).chart
            XCTAssertEqual(chart.phase, .hunting, "clean \(index + 1)")
            day = DayKey.adding(days: 1, to: day, calendar: calendar) ?? day
        }
        chart = RoundFold.markClean(dayKey: day, on: chart).chart
        XCTAssertEqual(chart.phase, .cleared)
        XCTAssertEqual(chart.runs.last?.dayKeys.count, 7)
    }

    func testPersistenceRoundTripAndBackup() async throws {
        let store = ChartStore(directory: directory, suiteName: suite)
        await store.load(allowSeed: false)
        let today = DayKey.make(from: Date(), calendar: DayKey.stable)
        let refusal = await store.pick(name: "Almond butter", dayKey: today)
        XCTAssertNil(refusal)
        let marked = await store.markClean(dayKey: today)
        XCTAssertNil(marked)
        await store.flush()

        let reloaded = ChartStore(directory: directory, suiteName: suite)
        await reloaded.load(allowSeed: false)
        let chart = await reloaded.chart
        XCTAssertEqual(chart.phase, .hunting)
        XCTAssertEqual(chart.sessions.last?.suspect?.name, "Almond butter")
        XCTAssertEqual(chart.sessions.last?.cleans.map(\.dayKey), [today])
        XCTAssertNil(chart.blank)
        XCTAssertEqual(chart.books.map(\.name), ["Almond butter"])

        guard let nextDay = DayKey.adding(days: 1, to: today, calendar: DayKey.stable) else {
            XCTFail("Missing next day")
            return
        }
        let logged = await reloaded.logIntake(name: "Lunch tin", dayKey: nextDay)
        XCTAssertNil(logged)
        await reloaded.flush()

        let file = directory.appendingPathComponent("spr.chart.v1.json")
        let backup = file.appendingPathExtension("backup")
        XCTAssertNotNil(try? Data(contentsOf: backup))
        try Data("not-json".utf8).write(to: file, options: .atomic)
        let restored = ChartStore(directory: directory, suiteName: suite)
        await restored.load(allowSeed: false)
        let again = await restored.chart
        XCTAssertEqual(again.notice, "The board file was damaged. Restored the previous copy.")
        XCTAssertEqual(again.sessions.last?.suspect?.name, "Almond butter")
        XCTAssertEqual(again.sessions.last?.cleans.map(\.dayKey), [today])
        XCTAssertTrue(again.sessions.last?.intakes.isEmpty ?? false)

        await restored.resetAllData()
        let reset = ChartStore(directory: directory, suiteName: suite)
        await reset.load(allowSeed: false)
        let empty = await reset.chart
        XCTAssertTrue(empty.sessions.isEmpty)
        XCTAssertNotNil(empty.blank)
        XCTAssertNil(empty.notice)
    }

    func testSimulatorSeedShape() {
        let calendar = DayKey.stable
        let today = DayKey.make(from: Date(), calendar: calendar)
        let chart = Chart.demo(today: today, calendar: calendar)
        XCTAssertTrue(chart.onboardingComplete)
        XCTAssertEqual(chart.books.count, 4)
        XCTAssertEqual(chart.phase, .hunting)
        XCTAssertEqual(chart.sessions.last?.suspect?.name, "Almond butter")
        XCTAssertFalse(chart.sessions.last?.cleans.contains { $0.dayKey == today } ?? true)
        XCTAssertEqual(chart.sessions.filter { $0.bust != nil }.count, 1)
        XCTAssertEqual(chart.sessions.filter { $0.cleared != nil }.count, 1)
        XCTAssertNil(chart.blank)
        XCTAssertGreaterThan(chart.sessions.last?.cleans.count ?? 0, 1)
        XCTAssertLessThan(chart.sessions.last?.cleans.count ?? 0, RoundFold.clearSpan)
    }

    func testReviewLaunchParsesScreenArgument() {
        XCTAssertEqual(ReviewLaunch.screen(in: ["Suspectround", "-ReviewScreen", "today"]), "today")
        XCTAssertEqual(ReviewLaunch.screen(in: ["Suspectround", "-ReviewScreen", "log"]), "log")
        XCTAssertEqual(ReviewLaunch.screen(in: ["Suspectround", "-ReviewScreen", "goals"]), "goals")
        XCTAssertEqual(ReviewLaunch.screen(in: ["Suspectround", "-ReviewScreen", "settings"]), "settings")
        XCTAssertEqual(ReviewLaunch.screen(in: ["Suspectround", "-ReviewScreen", "naming"]), "naming")
        XCTAssertEqual(ReviewLaunch.screen(in: ["Suspectround", "-ReviewScreen", "intake"]), "intake")
        XCTAssertEqual(ReviewLaunch.screen(in: ["Suspectround", "-ReviewScreen", "bodymap"]), "bodymap")
        XCTAssertNil(ReviewLaunch.screen(in: ["Suspectround"]))
        XCTAssertNil(ReviewLaunch.screen(in: ["Suspectround", "-ReviewScreen"]))
        XCTAssertNil(ReviewLaunch.screen(in: ["Suspectround", "-ReviewScreen", ""]))
    }

    @MainActor
    func testBoardRefusesIdleMark() async {
        let board = RoundBoard(store: ChartStore(directory: directory, suiteName: suite), allowSeed: false)
        await board.load()
        let today = DayKey.make(from: Date(), calendar: DayKey.stable)
        await board.markClean(dayKey: today)
        let idleRefusal = board.refusal
        XCTAssertEqual(idleRefusal, .markOnIdle)
        let blank = board.isBlank
        XCTAssertTrue(blank)
        await board.pick(name: "Soy yogurt", dayKey: today)
        let pickRefusal = board.refusal
        XCTAssertNil(pickRefusal)
        let phase = board.phase
        XCTAssertEqual(phase, .hunting)
        let name = board.suspectName
        XCTAssertEqual(name, "Soy yogurt")
        await board.markClean(dayKey: today)
        let count = board.cleanCount
        XCTAssertEqual(count, 1)
    }

    func testRetailCodePadsUpcAAndKeepsDigitRuns() {
        XCTAssertEqual(RetailCode.candidates(in: "https://pack.test/012345678905"), ["0012345678905"])
        XCTAssertEqual(RetailCode.candidates(in: "lot 12345678"), ["12345678"])
        XCTAssertEqual(RetailCode.candidates(in: "1234567890123"), ["1234567890123"])
        XCTAssertTrue(RetailCode.candidates(in: "1234567").isEmpty)
    }
}
