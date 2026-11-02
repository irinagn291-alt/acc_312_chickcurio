import Foundation

/// One root record. Islands are body regions, Books are named suspect products,
/// Sessions are rounds and their phase, Runs are consecutive clean streaks,
/// and Rhumbs are the rotation ledger. Marks live inside those buckets.
struct Chart: Codable, Sendable, Equatable {
    var schemaVersion: Int
    var islands: [Island]
    var books: [Book]
    var sessions: [Session]
    var runs: [Run]
    var rhumbs: [Rhumb]
    var blank: Blank?
    var onboardingComplete: Bool
    var notice: String?

    static let schema = 1

    static func fresh() -> Chart {
        Chart(
            schemaVersion: schema,
            islands: [],
            books: [],
            sessions: [],
            runs: [],
            rhumbs: [],
            blank: Blank(id: UUID()),
            onboardingComplete: false,
            notice: nil
        )
    }

    /// Last busted product stays ineligible until a later round is Cleared.
    var bannedSuspectName: String? {
        var ban: String?
        for session in sessions {
            if session.cleared != nil {
                ban = nil
            }
            if let bust = session.bust {
                ban = bust.productName
            }
        }
        return ban
    }

    var phase: RoundPhase {
        sessions.last?.phase ?? .idle
    }

    var cleanCount: Int {
        guard let session = sessions.last, session.phase == .hunting || session.phase == .cleared else {
            return sessions.last?.cleans.count ?? 0
        }
        return session.cleans.count
    }

    mutating func ensureBook(named name: String) -> Book {
        if let existing = books.first(where: {
            $0.name.compare(name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }) {
            return existing
        }
        let book = Book(id: UUID(), name: name)
        books.append(book)
        return book
    }

    init(
        schemaVersion: Int,
        islands: [Island],
        books: [Book],
        sessions: [Session],
        runs: [Run],
        rhumbs: [Rhumb],
        blank: Blank?,
        onboardingComplete: Bool,
        notice: String?
    ) {
        self.schemaVersion = schemaVersion
        self.islands = islands
        self.books = books
        self.sessions = sessions
        self.runs = runs
        self.rhumbs = rhumbs
        self.blank = blank
        self.onboardingComplete = onboardingComplete
        self.notice = notice
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let version = try container.decode(Int.self, forKey: .schemaVersion)
        switch version {
        case 1:
            schemaVersion = version
            islands = try container.decode([Island].self, forKey: .islands)
            books = try container.decode([Book].self, forKey: .books)
            sessions = try container.decode([Session].self, forKey: .sessions)
            runs = try container.decode([Run].self, forKey: .runs)
            rhumbs = try container.decode([Rhumb].self, forKey: .rhumbs)
            blank = try container.decodeIfPresent(Blank.self, forKey: .blank)
            onboardingComplete = try container.decode(Bool.self, forKey: .onboardingComplete)
            notice = try container.decodeIfPresent(String.self, forKey: .notice)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .schemaVersion,
                in: container,
                debugDescription: "Unknown chart schema \(version)."
            )
        }
    }
}

/// Body region tagged from a flare. Islands live on the chart, not in a second store.
struct Island: Codable, Sendable, Equatable, Identifiable {
    var id: UUID
    var name: String
}

/// A product the shelf can pick. Books are the named suspects.
struct Book: Codable, Sendable, Equatable, Identifiable {
    var id: UUID
    var name: String
}

/// One elimination round and the phase the fold has reached.
struct Session: Codable, Sendable, Equatable, Identifiable {
    var id: UUID
    var phase: RoundPhase
    var suspect: SuspectMark?
    var cleans: [CleanMark]
    var flares: [FlareMark]
    var bust: BustMark?
    var cleared: ClearedMark?
    var intakes: [Intake]
}

/// Consecutive clean day keys for one session. The count shown on the board
/// is derived from these keys. It is not stored as a separate total.
struct Run: Codable, Sendable, Equatable, Identifiable {
    var id: UUID
    var sessionID: UUID
    var dayKeys: [Int]
}

/// One line in the rotation ledger, written when Rotate folds a bust to Idle.
struct Rhumb: Codable, Sendable, Equatable, Identifiable {
    var id: UUID
    var mark: RotateMark
}
