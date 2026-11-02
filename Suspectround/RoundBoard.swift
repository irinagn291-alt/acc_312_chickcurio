import Foundation
import Observation

/// Presentation seam between the chart and the calendar. Views read phase,
/// the live clean count, and a refusal. They do not touch the file or the
/// UserDefaults key. Mark-the-day, pick, and rotate all go through the fold.
@MainActor
@Observable
final class RoundBoard {
    private let store: ChartStore
    private let allowSeed: Bool
    private var loadTask: Task<Void, Never>?
    private(set) var chart: Chart
    private(set) var refusal: RoundRefusal?
    private(set) var cleanCount: Int
    private(set) var isReady = false
    private(set) var isBusy = false
    private(set) var commitTick = 0
    private(set) var loadError: String?

    init(store: ChartStore, allowSeed: Bool) {
        self.store = store
        self.allowSeed = allowSeed
        self.chart = .fresh()
        self.cleanCount = 0
    }

    var phase: RoundPhase { chart.phase }

    var isBlank: Bool { chart.blank != nil && chart.sessions.isEmpty }

    var suspectName: String? { chart.sessions.last?.suspect?.name }

    func load() async {
        if isReady {
            await pull()
            return
        }
        if let loadTask {
            await loadTask.value
            return
        }
        let work = Task { @MainActor in
            await store.load(allowSeed: allowSeed)
            await pull()
            isReady = true
        }
        loadTask = work
        await work.value
        loadTask = nil
    }

    func pick(name: String, dayKey: Int) async {
        await commit { await store.pick(name: name, dayKey: dayKey) }
    }

    func markClean(dayKey: Int) async {
        await commit { await store.markClean(dayKey: dayKey) }
    }

    func markFlare(dayKey: Int, islandID: UUID? = nil) async {
        await commit { await store.markFlare(dayKey: dayKey, islandID: islandID) }
    }

    func rotate(dayKey: Int) async {
        await commit { await store.rotate(dayKey: dayKey) }
    }

    func logIntake(name: String, dayKey: Int) async {
        await commit { await store.logIntake(name: name, dayKey: dayKey) }
    }

    func tagPlace(name: String, dayKey: Int) async {
        await commit { await store.tagPlace(name: name, dayKey: dayKey) }
    }

    func setOnboardingComplete(_ complete: Bool) async {
        isBusy = true
        await store.setOnboardingComplete(complete)
        await pull()
        isBusy = false
    }

    func resetAllData() async {
        isBusy = true
        await store.resetAllData()
        refusal = nil
        await pull()
        isBusy = false
    }

    func flush() async {
        await store.flush()
    }

    private func commit(_ work: () async -> RoundRefusal?) async {
        isBusy = true
        refusal = await work()
        await pull()
        if refusal == nil {
            commitTick += 1
        }
        isBusy = false
    }

    private func pull() async {
        chart = await store.chart
        cleanCount = chart.cleanCount
        loadError = await store.lastError ?? chart.notice
    }
}
