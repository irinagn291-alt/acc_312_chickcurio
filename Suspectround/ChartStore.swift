import Foundation

/// The only persistence seam. Screens ask ChartStore to fold a mark and save.
/// The in-memory chart is the source of truth. The file and the single
/// UserDefaults key `spr.chart.v1` are projections of that chart.
actor ChartStore {
    static let storageKey = "spr.chart.v1"
    static let demoKey = "spr.demo.v1"
    private static let debounceNanoseconds: UInt64 = 400_000_000

    private(set) var chart: Chart
    private(set) var lastError: String?
    private let directory: URL
    private let suiteName: String?
    private var pendingSave: Task<Void, Never>?

    /// `suiteName` nil uses the app's standard defaults. Tests pass a private suite name
    /// so the actor opens UserDefaults itself and the reference never crosses actors.
    init(directory: URL, suiteName: String?) {
        self.chart = .fresh()
        self.directory = directory
        self.suiteName = suiteName
    }

    private func defaults() -> UserDefaults {
        if let suiteName, let suite = UserDefaults(suiteName: suiteName) {
            return suite
        }
        return .standard
    }

    static func applicationSupportDirectory() -> URL {
        let folder = "ChickCurio"
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
                .appendingPathComponent(folder, isDirectory: true)
        }
        return base.appendingPathComponent(folder, isDirectory: true)
    }

    func load(allowSeed: Bool) async {
        let file = fileURL
        let mainData = read(file)
        if let mainData, let decoded = decode(mainData) {
            chart = decoded
            await installSeedIfNeeded(allowSeed: allowSeed)
            return
        }
        if mainData != nil {
            let backupData = read(backupURL)
            if let backupData, let decoded = decode(backupData) {
                chart = decoded
                chart.notice = "The board file was damaged. Restored the previous copy."
                await writeNow()
                return
            }
            chart = .fresh()
            chart.notice = "The board file was damaged. Started empty."
            return
        }
        if let stored = defaults().data(forKey: Self.storageKey), let decoded = decode(stored) {
            chart = decoded
            await installSeedIfNeeded(allowSeed: allowSeed)
            return
        }
        if defaults().data(forKey: Self.storageKey) != nil {
            chart = .fresh()
            chart.notice = "Saved board could not be read. Started empty."
            return
        }
        chart = .fresh()
        await installSeedIfNeeded(allowSeed: allowSeed)
    }

    @discardableResult
    func pick(name: String, dayKey: Int) -> RoundRefusal? {
        let applied = RoundFold.pick(name: name, dayKey: dayKey, on: chart)
        return commit(applied)
    }

    @discardableResult
    func markClean(dayKey: Int) -> RoundRefusal? {
        let applied = RoundFold.markClean(dayKey: dayKey, on: chart)
        return commit(applied)
    }

    @discardableResult
    func markFlare(dayKey: Int, islandID: UUID?) -> RoundRefusal? {
        let applied = RoundFold.markFlare(dayKey: dayKey, islandID: islandID, on: chart)
        return commit(applied)
    }

    @discardableResult
    func rotate(dayKey: Int) -> RoundRefusal? {
        let applied = RoundFold.rotate(dayKey: dayKey, on: chart)
        return commit(applied)
    }

    @discardableResult
    func logIntake(name: String, dayKey: Int) -> RoundRefusal? {
        let applied = RoundFold.logIntake(name: name, dayKey: dayKey, on: chart)
        return commit(applied)
    }

    /// Writes the onboarding flag without folding the round.
    func setOnboardingComplete(_ complete: Bool) async {
        chart.onboardingComplete = complete
        await writeNow()
    }

    /// Tags the flare on `dayKey` with a body region. Does not change phase.
    @discardableResult
    func tagPlace(name: String, dayKey: Int) -> RoundRefusal? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .emptyName }
        guard DayKey.isPlausible(dayKey) else { return .invalidDay }
        guard let sessionIndex = chart.sessions.lastIndex(where: { session in
            session.flares.contains { $0.dayKey == dayKey }
        }) else {
            chart.notice = "No flare on that day. Mark a flare first."
            scheduleSave()
            return .intakeRefused
        }
        var next = chart
        let islandID: UUID
        if let found = next.islands.first(where: {
            $0.name.compare(trimmed, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }) {
            islandID = found.id
        } else {
            let created = Island(id: UUID(), name: trimmed)
            next.islands.append(created)
            islandID = created.id
        }
        if let flareIndex = next.sessions[sessionIndex].flares.firstIndex(where: { $0.dayKey == dayKey }) {
            next.sessions[sessionIndex].flares[flareIndex].islandID = islandID
        }
        next.notice = nil
        chart = next
        scheduleSave()
        return nil
    }

    func resetAllData() async {
        pendingSave?.cancel()
        pendingSave = nil
        chart = .fresh()
        defaults().removeObject(forKey: Self.storageKey)
        defaults().removeObject(forKey: Self.demoKey)
        remove(fileURL)
        remove(backupURL)
        await writeNow()
    }

    func scheduleSave() {
        pendingSave?.cancel()
        pendingSave = Task { [weak self] in
            try? await Task.sleep(nanoseconds: Self.debounceNanoseconds)
            guard let self, !Task.isCancelled else { return }
            await self.writeNow()
        }
    }

    func flush() async {
        pendingSave?.cancel()
        pendingSave = nil
        await writeNow()
    }

    private func commit(_ applied: RoundApply) -> RoundRefusal? {
        guard applied.refusal == nil else { return applied.refusal }
        chart = applied.chart
        scheduleSave()
        return nil
    }

    private func installSeedIfNeeded(allowSeed: Bool) async {
        #if targetEnvironment(simulator)
        guard allowSeed else { return }
        guard defaults().bool(forKey: Self.demoKey) == false else { return }
        guard chart.sessions.isEmpty, chart.notice == nil else { return }
        let today = DayKey.make(from: Date(), calendar: DayKey.stable)
        chart = Chart.demo(today: today)
        await writeNow()
        if lastError == nil {
            defaults().set(true, forKey: Self.demoKey)
        }
        #else
        _ = allowSeed
        #endif
    }

    private var fileURL: URL {
        directory.appendingPathComponent("spr.chart.v1.json")
    }

    private var backupURL: URL {
        fileURL.appendingPathExtension("backup")
    }

    private func writeNow() async {
        let snapshot = chart
        let target = fileURL
        let backup = backupURL
        let encoded: Data
        do {
            encoded = try JSONEncoder().encode(snapshot)
        } catch {
            lastError = "Save failed. The board could not be encoded."
            return
        }
        let previous = read(target)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            if let previous, decode(previous) != nil {
                try previous.write(to: backup, options: .atomic)
            }
            try encoded.write(to: target, options: .atomic)
            defaults().set(encoded, forKey: Self.storageKey)
            lastError = nil
        } catch {
            lastError = "Save failed. The board is still on screen."
        }
    }

    private func decode(_ data: Data) -> Chart? {
        do {
            return try JSONDecoder().decode(Chart.self, from: data)
        } catch {
            return nil
        }
    }

    private func read(_ url: URL) -> Data? {
        do {
            return try Data(contentsOf: url)
        } catch {
            return nil
        }
    }

    private func remove(_ url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            lastError = "Reset could not remove the old board file."
        }
    }
}
