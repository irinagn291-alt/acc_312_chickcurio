import SwiftUI

struct ReportView: View {
    var board: RoundBoard

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.s16) {
                if let loadError = board.loadError {
                    StatusBanner(title: loadError) {
                        Task { await board.load() }
                    }
                }
                if board.chart.sessions.isEmpty && board.chart.rhumbs.isEmpty {
                    empty
                } else {
                    populated
                }
            }
            .padding(Spacing.s24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(DesignTokens.bg)
    }

    private var populated: some View {
        VStack(alignment: .leading, spacing: Spacing.s16) {
            VStack(alignment: .leading, spacing: Spacing.s8) {
                Text("Busted")
                    .font(TypeScale.font(.caption))
                    .foregroundStyle(DesignTokens.muted)
                Text(bustCount, format: .number.precision(.fractionLength(0)))
                    .font(TypeScale.font(.display, weight: .bold))
                    .foregroundStyle(DesignTokens.ink)
                    .contentTransition(.numericText(value: Double(bustCount)))
                    .animation(Motion.stateChange, value: bustCount)
                    .fixedSize(horizontal: true, vertical: true)
                Text("Cleared")
                    .font(TypeScale.font(.caption))
                    .foregroundStyle(DesignTokens.muted)
                Text(clearedCount, format: .number.precision(.fractionLength(0)))
                    .font(TypeScale.font(.title, weight: .bold))
                    .foregroundStyle(DesignTokens.ink)
                    .contentTransition(.numericText(value: Double(clearedCount)))
                    .animation(Motion.stateChange, value: clearedCount)
                    .fixedSize(horizontal: true, vertical: true)
            }
            .padding(Spacing.s16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            section(title: "Failed foods", rows: busts)
            section(title: "Cleared foods", rows: cleared)
            section(title: "Rotated off", rows: rotations)
            ShareLink(item: exportText) {
                Text("Export ledger")
                    .frame(maxWidth: .infinity, minHeight: Spacing.s48)
                    .contentShape(Rectangle())
            }
            .buttonStyle(SoftCardButtonStyle(kind: .quiet))
        }
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: Spacing.s16) {
            Image("spr_TwistHero")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .containerRelativeFrame(.vertical, count: 10, span: 3, spacing: Spacing.s16)
                .background(DesignTokens.surface)
                .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                .accessibilityHidden(true)
            Text("No finished week yet.")
                .font(TypeScale.font(.display, weight: .bold))
                .foregroundStyle(DesignTokens.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text("Mark days until a food clears or busts.")
                .font(TypeScale.font(.body))
                .foregroundStyle(DesignTokens.muted)
                .fixedSize(horizontal: false, vertical: true)
            ShareLink(item: exportText) {
                Text("Export ledger")
                    .frame(maxWidth: .infinity, minHeight: Spacing.s48)
                    .contentShape(Rectangle())
            }
            .buttonStyle(SoftCardButtonStyle(kind: .quiet))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func section(title: String, rows: [LedgerRow]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s8) {
            Text(title)
                .font(TypeScale.font(.headline, weight: .bold))
                .foregroundStyle(DesignTokens.ink)
            if rows.isEmpty {
                Text("unknown")
                    .font(TypeScale.font(.body))
                    .foregroundStyle(DesignTokens.muted)
                    .frame(minHeight: Spacing.s48, alignment: .leading)
            } else {
                ForEach(rows) { row in
                    HStack(spacing: Spacing.s8) {
                        Text(row.name)
                            .font(TypeScale.font(.body, weight: .bold))
                            .foregroundStyle(DesignTokens.ink)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        dayText(row.dayKey)
                            .layoutPriority(1)
                    }
                    .frame(minHeight: Spacing.s48)
                }
            }
        }
        .padding(Spacing.s16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }

    private func dayText(_ day: Int) -> some View {
        Group {
            if let date = DayKey.date(from: day, calendar: .current) {
                Text(date, format: .dateTime.month(.abbreviated).day())
            } else {
                Text("unknown")
            }
        }
        .font(TypeScale.font(.caption))
        .foregroundStyle(DesignTokens.muted)
    }

    private var bustCount: Int { busts.count }
    private var clearedCount: Int { cleared.count }

    private var busts: [LedgerRow] {
        board.chart.sessions.compactMap { session in
            guard let bust = session.bust else { return nil }
            return LedgerRow(id: bust.id, name: bust.productName, dayKey: bust.dayKey)
        }
    }

    private var cleared: [LedgerRow] {
        board.chart.sessions.compactMap { session in
            guard let mark = session.cleared else { return nil }
            return LedgerRow(id: mark.id, name: mark.productName, dayKey: mark.dayKey)
        }
    }

    private var rotations: [LedgerRow] {
        board.chart.rhumbs.map { rhumb in
            LedgerRow(id: rhumb.id, name: rhumb.mark.productName, dayKey: rhumb.mark.dayKey)
        }
    }

    private var exportText: String {
        var lines: [String] = []
        lines.append("Busted \(bustCount.formatted(.number.precision(.fractionLength(0))))")
        lines.append("Cleared \(clearedCount.formatted(.number.precision(.fractionLength(0))))")
        for row in busts {
            lines.append("Failed \(row.name)")
        }
        for row in cleared {
            lines.append("Cleared \(row.name)")
        }
        for row in rotations {
            lines.append("Rotated \(row.name)")
        }
        return lines.joined(separator: "\n")
    }
}

private struct LedgerRow: Identifiable {
    var id: UUID
    var name: String
    var dayKey: Int
}
