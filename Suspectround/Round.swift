import Foundation

/// Round ADT. The elimination round is a fold over day keys for one suspect.
/// Phases are Idle, Hunting, Cleared, and Busted. An empty chart writes Blank.
/// Pick writes SuspectMark and folds Idle or Cleared to Hunting.
/// Seven consecutive Clean marks with no Flare fold Hunting to Cleared.
/// A Flare writes FlareMark and BustMark and folds Hunting to Busted.
/// Rotate clears SuspectMark and folds Busted to Idle.
/// Mark on Idle or Busted is refused. A second Pick while Hunting is refused.
/// Pick will not repeat the last busted suspect until a round is Cleared.
enum RoundPhase: String, Codable, Sendable, Equatable {
    case idle
    case hunting
    case cleared
    case busted
}

enum RoundRefusal: String, Sendable, Equatable {
    case markOnIdle
    case markOnBusted
    case markOnCleared
    case secondPick
    case pickWhileBusted
    case repeatsLastBust
    case invalidDay
    case duplicateDay
    case rotateWhileNotBusted
    case emptyName
    case intakeRefused
}

struct RoundApply: Sendable, Equatable {
    var chart: Chart
    var refusal: RoundRefusal?
}

enum RoundFold {
    static let clearSpan = 7

    static func pick(name: String, dayKey: Int, on chart: Chart) -> RoundApply {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return refused(.emptyName, chart) }
        guard DayKey.isPlausible(dayKey) else { return refused(.invalidDay, chart) }
        if let session = chart.sessions.last {
            switch session.phase {
            case .hunting:
                return refused(.secondPick, chart)
            case .busted:
                return refused(.pickWhileBusted, chart)
            case .idle, .cleared:
                break
            }
        }
        if let ban = chart.bannedSuspectName,
           ban.compare(trimmed, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame {
            return refused(.repeatsLastBust, chart)
        }
        var next = chart
        next.blank = nil
        next.notice = nil
        let book = next.ensureBook(named: trimmed)
        let session = Session(
            id: UUID(),
            phase: .hunting,
            suspect: SuspectMark(id: UUID(), bookID: book.id, name: book.name, dayKey: dayKey),
            cleans: [],
            flares: [],
            bust: nil,
            cleared: nil,
            intakes: []
        )
        next.sessions.append(session)
        return RoundApply(chart: next, refusal: nil)
    }

    static func markClean(dayKey: Int, on chart: Chart) -> RoundApply {
        guard let index = openIndex(in: chart) else {
            return refused(.markOnIdle, chart)
        }
        var next = chart
        switch next.sessions[index].phase {
        case .idle:
            return refused(.markOnIdle, chart)
        case .busted:
            return refused(.markOnBusted, chart)
        case .cleared:
            return refused(.markOnCleared, chart)
        case .hunting:
            break
        }
        guard DayKey.isPlausible(dayKey) else { return refused(.invalidDay, chart) }
        if dayTaken(dayKey, in: next.sessions[index]) {
            return refused(.duplicateDay, chart)
        }
        next.notice = nil
        next.sessions[index].cleans.append(CleanMark(id: UUID(), dayKey: dayKey))
        let keys = next.sessions[index].cleans.map(\.dayKey)
        upsertRun(sessionID: next.sessions[index].id, dayKeys: keys, on: &next)
        if next.sessions[index].flares.isEmpty, next.sessions[index].cleans.count >= clearSpan {
            let product = next.sessions[index].suspect?.name ?? ""
            next.sessions[index].phase = .cleared
            next.sessions[index].cleared = ClearedMark(id: UUID(), dayKey: dayKey, productName: product)
        }
        return RoundApply(chart: next, refusal: nil)
    }

    static func markFlare(dayKey: Int, islandID: UUID?, on chart: Chart) -> RoundApply {
        guard let index = openIndex(in: chart) else {
            return refused(.markOnIdle, chart)
        }
        var next = chart
        switch next.sessions[index].phase {
        case .idle:
            return refused(.markOnIdle, chart)
        case .busted:
            return refused(.markOnBusted, chart)
        case .cleared:
            return refused(.markOnCleared, chart)
        case .hunting:
            break
        }
        guard DayKey.isPlausible(dayKey) else { return refused(.invalidDay, chart) }
        if dayTaken(dayKey, in: next.sessions[index]) {
            return refused(.duplicateDay, chart)
        }
        let product = next.sessions[index].suspect?.name ?? ""
        next.notice = nil
        next.sessions[index].flares.append(FlareMark(id: UUID(), dayKey: dayKey, islandID: islandID))
        next.sessions[index].bust = BustMark(id: UUID(), dayKey: dayKey, productName: product)
        next.sessions[index].phase = .busted
        return RoundApply(chart: next, refusal: nil)
    }

    static func rotate(dayKey: Int, on chart: Chart) -> RoundApply {
        guard let index = openIndex(in: chart) else {
            return refused(.rotateWhileNotBusted, chart)
        }
        guard chart.sessions[index].phase == .busted else {
            return refused(.rotateWhileNotBusted, chart)
        }
        guard DayKey.isPlausible(dayKey) else { return refused(.invalidDay, chart) }
        var next = chart
        let product = next.sessions[index].suspect?.name ?? next.sessions[index].bust?.productName ?? ""
        next.sessions[index].suspect = nil
        next.sessions[index].phase = .idle
        next.notice = nil
        let mark = RotateMark(id: UUID(), dayKey: dayKey, productName: product)
        next.rhumbs.append(Rhumb(id: UUID(), mark: mark))
        return RoundApply(chart: next, refusal: nil)
    }

    static func logIntake(name: String, dayKey: Int, on chart: Chart) -> RoundApply {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return refused(.emptyName, chart) }
        guard let index = openIndex(in: chart), chart.sessions[index].phase == .hunting else {
            return refused(.intakeRefused, chart)
        }
        guard DayKey.isPlausible(dayKey) else { return refused(.invalidDay, chart) }
        var next = chart
        next.sessions[index].intakes.append(Intake(id: UUID(), dayKey: dayKey, name: trimmed))
        return RoundApply(chart: next, refusal: nil)
    }

    /// Overlap is a family score. It does not write a BustMark and does not
    /// change the phase, even when the ratio is high.
    static func applyingOverlapScore(_ score: Double?, to chart: Chart) -> Chart {
        _ = score
        return chart
    }

    private static func openIndex(in chart: Chart) -> Int? {
        chart.sessions.indices.last
    }

    private static func dayTaken(_ dayKey: Int, in session: Session) -> Bool {
        session.cleans.contains { $0.dayKey == dayKey } || session.flares.contains { $0.dayKey == dayKey }
    }

    private static func upsertRun(sessionID: UUID, dayKeys: [Int], on chart: inout Chart) {
        if let index = chart.runs.firstIndex(where: { $0.sessionID == sessionID }) {
            chart.runs[index].dayKeys = dayKeys
        } else {
            chart.runs.append(Run(id: UUID(), sessionID: sessionID, dayKeys: dayKeys))
        }
    }

    private static func refused(_ refusal: RoundRefusal, _ chart: Chart) -> RoundApply {
        RoundApply(chart: chart, refusal: refusal)
    }
}
