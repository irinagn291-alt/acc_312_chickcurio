import SwiftUI

struct TimelineView: View {
    var board: RoundBoard
    var today: Int
    var openNaming: () -> Void
    var openIntake: () -> Void
    var openReport: () -> Void
    var openBodyMap: () -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @GestureState private var dragIntent: DragIntent?

    private var wide: Bool {
        horizontalSizeClass == .regular && dynamicTypeSize.isAccessibilitySize == false
    }

    private var session: Session? { board.chart.sessions.last }

    private var todayTaken: Bool {
        guard let session else { return false }
        return session.cleans.contains { $0.dayKey == today } || session.flares.contains { $0.dayKey == today }
    }

    private var canMark: Bool {
        allowsMark(on: today)
    }

    private func allowsMark(on day: Int) -> Bool {
        guard board.phase == .hunting, board.isBusy == false else { return false }
        guard let session else { return false }
        let taken = session.cleans.contains { $0.dayKey == day } || session.flares.contains { $0.dayKey == day }
        return taken == false
    }

    private var bustCount: Int {
        board.chart.sessions.reduce(into: 0) { count, item in
            if item.bust != nil { count += 1 }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.s24) {
                if let loadError = board.loadError {
                    StatusBanner(title: loadError) {
                        Task { await board.load() }
                    }
                }
                Text("One suspect. Mark today clean or flare.")
                    .font(TypeScale.font(.display, weight: .bold))
                    .foregroundStyle(DesignTokens.ink)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if wide {
                    Grid(alignment: .topLeading, horizontalSpacing: Spacing.s16, verticalSpacing: Spacing.s16) {
                        GridRow {
                            dayBoard.gridCellColumns(2)
                            sideRail.gridCellColumns(1)
                        }
                        GridRow {
                            earlierDays.gridCellColumns(3)
                        }
                        GridRow {
                            activity.gridCellColumns(3)
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: Spacing.s16) {
                        dayBoard
                        sideRail
                        earlierDays
                        activity
                    }
                }
            }
            .padding(Spacing.s24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentMargins(.bottom, Spacing.s32, for: .scrollContent)
        .background(DesignTokens.bg)
        .sensoryFeedback(.success, trigger: board.commitTick)
    }

    /// Open-day mark board — primary job and next tap above the fold.
    private var dayBoard: some View {
        VStack(alignment: .leading, spacing: Spacing.s12) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.s12) {
                VStack(alignment: .leading, spacing: Spacing.s4) {
                    Text("Clean days")
                        .font(TypeScale.font(.caption))
                        .foregroundStyle(DesignTokens.muted)
                    Text(board.cleanCount, format: .number.precision(.fractionLength(0)))
                        .font(TypeScale.font(.display, weight: .bold))
                        .foregroundStyle(DesignTokens.ink)
                        .contentTransition(.numericText(value: Double(board.cleanCount)))
                        .animation(Motion.stateChange, value: board.cleanCount)
                        .fixedSize(horizontal: true, vertical: true)
                        .accessibilityLabel("Clean days")
                }
                Spacer(minLength: Spacing.s8)
                Text(dragWord)
                    .font(TypeScale.font(.caption, weight: .bold))
                    .foregroundStyle(DesignTokens.accent)
                    .frame(minHeight: Spacing.s48)
            }
            if let copy = refusalCopy(board.refusal) {
                Text(copy)
                    .font(TypeScale.font(.caption))
                    .foregroundStyle(DesignTokens.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            markActions
        }
        .padding(Spacing.s16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .gesture(markDrag)
        .accessibilityHint("Drag right to mark clean. Drag left to mark flare.")
    }

    private var dragWord: String {
        switch dragIntent {
        case .clean:
            return "Clean"
        case .flare:
            return "Flare"
        case nil:
            return todayTaken ? "Marked" : "Open"
        }
    }

    private var markDrag: some Gesture {
        DragGesture(minimumDistance: Spacing.s12)
            .updating($dragIntent) { value, state, _ in
                if value.translation.width > Spacing.s12 {
                    state = .clean
                } else if value.translation.width < -Spacing.s12 {
                    state = .flare
                } else {
                    state = nil
                }
            }
            .onEnded { value in
                guard allowsMark(on: today) else { return }
                if value.translation.width > Spacing.s12 {
                    markClean(day: today)
                } else if value.translation.width < -Spacing.s12 {
                    markFlare(day: today)
                }
            }
    }

    @ViewBuilder
    private var markActions: some View {
        if board.phase == .hunting {
            Button(action: { markClean(day: today) }) {
                actionLabel("Clean", symbol: "checkmark", busy: board.isBusy)
            }
            .buttonStyle(SoftCardButtonStyle(kind: .accent))
            .disabled(canMark == false)
            Button(action: { markFlare(day: today) }) {
                actionLabel("Flare", symbol: "flame", busy: board.isBusy)
            }
            .buttonStyle(SoftCardButtonStyle(kind: .quiet))
            .disabled(canMark == false)
        } else if board.phase == .busted {
            Button(action: rotate) {
                actionLabel("Rotate off", symbol: "arrow.triangle.2.circlepath", busy: board.isBusy)
            }
            .buttonStyle(SoftCardButtonStyle(kind: .accent))
            .disabled(board.isBusy)
        } else {
            Button(action: openNaming) {
                actionLabel("Pick a food", symbol: "plus", busy: board.isBusy)
            }
            .buttonStyle(SoftCardButtonStyle(kind: .accent))
            .disabled(board.isBusy)
        }
    }

    private func actionLabel(_ title: String, symbol: String, busy: Bool) -> some View {
        ZStack {
            Label(title, systemImage: symbol)
                .labelStyle(.titleAndIcon)
                .opacity(busy ? 0 : 1)
            if busy {
                ProgressView()
                    .tint(DesignTokens.ink)
            }
        }
        .frame(maxWidth: .infinity, minHeight: Spacing.s48)
        .contentShape(Rectangle())
    }

    /// Compact suspect strip + Log food — secondary to the mark board.
    private var sideRail: some View {
        VStack(alignment: .leading, spacing: Spacing.s12) {
            Button(action: openNaming) {
                HStack(alignment: .center, spacing: Spacing.s12) {
                    Image("spr_TwistHero")
                        .resizable()
                        .scaledToFit()
                        .frame(width: Spacing.s48, height: Spacing.s48)
                        .padding(Spacing.s8)
                        .background(DesignTokens.surface)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: Spacing.s4) {
                        Text(board.suspectName ?? "unknown")
                            .font(TypeScale.font(.caption, weight: .bold))
                            .foregroundStyle(DesignTokens.ink)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Text(phaseWord)
                            .font(TypeScale.font(.caption))
                            .foregroundStyle(DesignTokens.muted)
                        HStack(spacing: Spacing.s8) {
                            Text("Busted")
                                .font(TypeScale.font(.caption))
                                .foregroundStyle(DesignTokens.muted)
                            Text(bustCount, format: .number.precision(.fractionLength(0)))
                                .font(TypeScale.font(.caption, weight: .bold))
                                .foregroundStyle(DesignTokens.ink)
                                .contentTransition(.numericText(value: Double(bustCount)))
                                .animation(Motion.stateChange, value: bustCount)
                                .layoutPriority(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, minHeight: Spacing.s48, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(ScaleOnlyButtonStyle())
            .accessibilityHint("Opens the food name.")
            Button(action: openIntake) {
                Label("Log food", systemImage: "plus")
                    .frame(maxWidth: .infinity, minHeight: Spacing.s48)
                    .contentShape(Rectangle())
            }
            .buttonStyle(SoftCardButtonStyle(kind: .quiet))
        }
        .padding(Spacing.s16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }

    private var earlierDays: some View {
        VStack(alignment: .leading, spacing: Spacing.s8) {
            Text(phaseWord)
                .font(TypeScale.font(.caption, weight: .bold))
                .foregroundStyle(DesignTokens.ink)
            ForEach(previousDays, id: \.self) { day in
                EarlierDayRow(
                    day: day,
                    resting: markWord(day),
                    symbol: markSymbol(day),
                    enabled: allowsMark(on: day),
                    markClean: { markClean(day: day) },
                    markFlare: { markFlare(day: day) }
                )
            }
        }
        .padding(Spacing.s16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }

    private var previousDays: [Int] {
        (1...6).compactMap { offset in
            DayKey.adding(days: -offset, to: today, calendar: .current)
        }
        .reversed()
    }

    private var phaseWord: String {
        switch board.phase {
        case .idle:
            return "Idle"
        case .hunting:
            return "Hunting"
        case .cleared:
            return "Cleared"
        case .busted:
            return "Busted"
        }
    }

    private func markWord(_ day: Int) -> String {
        guard let session else { return "Quiet" }
        if session.cleans.contains(where: { $0.dayKey == day }) { return "Clean" }
        if session.flares.contains(where: { $0.dayKey == day }) { return "Flare" }
        return "Quiet"
    }

    private func markSymbol(_ day: Int) -> String {
        switch markWord(day) {
        case "Clean":
            return "checkmark"
        case "Flare":
            return "flame"
        default:
            return "minus"
        }
    }

    private func dayLabel(_ day: Int) -> some View {
        Group {
            if let date = DayKey.date(from: day, calendar: .current) {
                Text(date, format: .dateTime.month(.abbreviated).day())
            } else {
                Text("unknown")
            }
        }
        .font(TypeScale.font(.caption))
        .foregroundStyle(DesignTokens.muted)
        .lineLimit(1)
    }

    private var activity: some View {
        VStack(alignment: .leading, spacing: Spacing.s8) {
            Text("Recent marks")
                .font(TypeScale.font(.caption, weight: .bold))
                .foregroundStyle(DesignTokens.ink)
            if flareNotes.isEmpty && clearedNotes.isEmpty && board.chart.rhumbs.isEmpty {
                Text("No finished week yet.")
                    .font(TypeScale.font(.caption))
                    .foregroundStyle(DesignTokens.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(clearedNotes) { note in
                readout(title: note.product, detail: "Cleared", day: note.dayKey)
            }
            ForEach(flareNotes) { note in
                Button(action: openBodyMap) {
                    HStack(spacing: Spacing.s8) {
                        VStack(alignment: .leading, spacing: Spacing.s4) {
                            Text(note.product)
                                .font(TypeScale.font(.caption, weight: .bold))
                                .foregroundStyle(DesignTokens.ink)
                                .lineLimit(1)
                                .truncationMode(.tail)
                            dayLabel(note.dayKey)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Text(note.place)
                            .font(TypeScale.font(.caption))
                            .foregroundStyle(DesignTokens.muted)
                            .lineLimit(1)
                        Text("Tag place")
                            .font(TypeScale.font(.caption, weight: .bold))
                            .foregroundStyle(DesignTokens.ink)
                            .layoutPriority(1)
                    }
                    .frame(minHeight: Spacing.s48)
                    .contentShape(Rectangle())
                }
                .buttonStyle(ScaleOnlyButtonStyle())
            }
            ForEach(board.chart.rhumbs) { rhumb in
                readout(title: rhumb.mark.productName, detail: "Rotated off", day: rhumb.mark.dayKey)
            }
            Button(action: openReport) {
                Text("Read the ledger")
                    .frame(maxWidth: .infinity, minHeight: Spacing.s48)
                    .contentShape(Rectangle())
            }
            .buttonStyle(SoftCardButtonStyle(kind: .quiet))
        }
        .padding(Spacing.s16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }

    private func readout(title: String, detail: String, day: Int) -> some View {
        HStack(spacing: Spacing.s8) {
            Text(title)
                .font(TypeScale.font(.caption, weight: .bold))
                .foregroundStyle(DesignTokens.ink)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
            dayLabel(day)
            Text(detail)
                .font(TypeScale.font(.caption))
                .foregroundStyle(DesignTokens.ink)
                .layoutPriority(1)
        }
        .frame(minHeight: Spacing.s48)
    }

    private var clearedNotes: [DayNote] {
        board.chart.sessions.compactMap { session in
            guard let cleared = session.cleared else { return nil }
            return DayNote(id: cleared.id, product: cleared.productName, place: "Cleared", dayKey: cleared.dayKey)
        }
    }

    private var flareNotes: [DayNote] {
        board.chart.sessions.flatMap { session in
            session.flares.map { flare in
                let place = board.chart.islands.first { $0.id == flare.islandID }?.name ?? "unknown"
                let product = session.bust?.productName ?? session.suspect?.name ?? "unknown"
                return DayNote(id: flare.id, product: product, place: place, dayKey: flare.dayKey)
            }
        }
    }

    private func markClean(day: Int) {
        Task { await board.markClean(dayKey: day) }
    }

    private func markFlare(day: Int) {
        Task { await board.markFlare(dayKey: day, islandID: nil) }
    }

    private func rotate() {
        Task { await board.rotate(dayKey: today) }
    }
}

private enum DragIntent: Equatable {
    case clean
    case flare
}

private struct EarlierDayRow: View {
    var day: Int
    var resting: String
    var symbol: String
    var enabled: Bool
    var markClean: () -> Void
    var markFlare: () -> Void

    @GestureState private var intent: DragIntent?
    @ScaledMetric(relativeTo: .caption) private var iconSide = Spacing.s24

    var body: some View {
        HStack(spacing: Spacing.s8) {
            Group {
                if let date = DayKey.date(from: day, calendar: .current) {
                    Text(date, format: .dateTime.month(.abbreviated).day())
                } else {
                    Text("unknown")
                }
            }
            .font(TypeScale.font(.caption))
            .foregroundStyle(DesignTokens.muted)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(liveWord)
                .font(TypeScale.font(.caption, weight: .bold))
                .foregroundStyle(DesignTokens.ink)
            Image(systemName: symbol)
                .font(TypeScale.font(.caption))
                .foregroundStyle(DesignTokens.ink)
                .frame(width: iconSide, height: iconSide)
                .accessibilityHidden(true)
        }
        .frame(minHeight: Spacing.s48)
        .contentShape(Rectangle())
        .gesture(drag)
        .accessibilityHint("Drag right to mark clean. Drag left to mark flare.")
    }

    private var liveWord: String {
        switch intent {
        case .clean:
            return "Clean"
        case .flare:
            return "Flare"
        case nil:
            return resting
        }
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: Spacing.s12)
            .updating($intent) { value, state, _ in
                if value.translation.width > Spacing.s12 {
                    state = .clean
                } else if value.translation.width < -Spacing.s12 {
                    state = .flare
                } else {
                    state = nil
                }
            }
            .onEnded { value in
                guard enabled else { return }
                if value.translation.width > Spacing.s12 {
                    markClean()
                } else if value.translation.width < -Spacing.s12 {
                    markFlare()
                }
            }
    }
}

private struct DayNote: Identifiable {
    var id: UUID
    var product: String
    var place: String
    var dayKey: Int
}
