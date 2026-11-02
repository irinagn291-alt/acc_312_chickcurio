import SwiftUI

struct BodyMapView: View {
    var board: RoundBoard
    @State private var chosen: UUID?
    @State private var missed = false

    private let places = ["Head", "Gut", "Skin", "Joints"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.s16) {
                if let loadError = board.loadError {
                    StatusBanner(title: loadError) {
                        Task { await board.load() }
                    }
                }
                if let flare = flares.last {
                    populated(flare)
                } else {
                    empty
                }
            }
            .padding(Spacing.s24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .background(DesignTokens.bg)
        .onAppear {
            chosen = flares.last?.id
        }
    }

    private func populated(_ flare: FlareNote) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s16) {
            Text(flare.product)
                .font(TypeScale.font(.display, weight: .bold))
                .foregroundStyle(DesignTokens.ink)
                .lineLimit(2)
                .truncationMode(.tail)
                .fixedSize(horizontal: false, vertical: true)
            Text(activePlace(fallback: flare))
                .font(TypeScale.font(.body))
                .foregroundStyle(DesignTokens.muted)
            if let copy = refusalCopy(board.refusal) {
                Text(copy)
                    .font(TypeScale.font(.body))
                    .foregroundStyle(DesignTokens.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(flares) { item in
                Button {
                    chosen = item.id
                } label: {
                    HStack(spacing: Spacing.s8) {
                        Text(item.product)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if let date = DayKey.date(from: item.dayKey, calendar: .current) {
                            Text(date, format: .dateTime.month(.abbreviated).day())
                                .layoutPriority(1)
                        }
                        Image(systemName: chosen == item.id ? "checkmark.circle.fill" : "circle")
                            .accessibilityHidden(true)
                    }
                    .frame(minHeight: Spacing.s48)
                    .contentShape(Rectangle())
                }
                .buttonStyle(SoftCardButtonStyle(kind: chosen == item.id ? .accent : .quiet))
            }
            Text("Tag place")
                .font(TypeScale.font(.headline, weight: .bold))
                .foregroundStyle(DesignTokens.ink)
            ForEach(places, id: \.self) { place in
                Button {
                    tag(place)
                } label: {
                    HStack(spacing: Spacing.s8) {
                        Text(place)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if activePlace(fallback: flare).caseInsensitiveCompare(place) == .orderedSame {
                            Image(systemName: "checkmark")
                                .accessibilityHidden(true)
                            Text("Tagged")
                        } else {
                            Text("Tag place")
                        }
                    }
                    .frame(minHeight: Spacing.s48)
                    .contentShape(Rectangle())
                }
                .buttonStyle(SoftCardButtonStyle(kind: .quiet))
                .disabled(board.isBusy || chosen == nil)
            }
        }
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: Spacing.s16) {
            Image("spr_BustToken")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .containerRelativeFrame(.vertical, count: 10, span: 3, spacing: Spacing.s16)
                .background(DesignTokens.surface)
                .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                .accessibilityHidden(true)
            Text("No flare yet.")
                .font(TypeScale.font(.display, weight: .bold))
                .foregroundStyle(DesignTokens.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text("Mark a flare on the open day.")
                .font(TypeScale.font(.body))
                .foregroundStyle(DesignTokens.muted)
                .fixedSize(horizontal: false, vertical: true)
            if missed {
                Text("No flare on that day. Mark a flare first.")
                    .font(TypeScale.font(.body))
                    .foregroundStyle(DesignTokens.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button {
                missed = true
            } label: {
                Text("Tag place")
                    .frame(maxWidth: .infinity, minHeight: Spacing.s48)
                    .contentShape(Rectangle())
            }
            .buttonStyle(SoftCardButtonStyle(kind: .accent))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var flares: [FlareNote] {
        board.chart.sessions.flatMap { session in
            session.flares.map { flare in
                let place = board.chart.islands.first { $0.id == flare.islandID }?.name ?? "unknown"
                let product = session.bust?.productName ?? session.suspect?.name ?? "unknown"
                return FlareNote(id: flare.id, dayKey: flare.dayKey, product: product, place: place)
            }
        }
    }

    private func activePlace(fallback: FlareNote) -> String {
        let id = chosen ?? fallback.id
        return flares.first { $0.id == id }?.place ?? fallback.place
    }

    private func tag(_ place: String) {
        guard let id = chosen ?? flares.last?.id else { return }
        guard let flare = flares.first(where: { $0.id == id }) else { return }
        Task { await board.tagPlace(name: place, dayKey: flare.dayKey) }
    }
}

private struct FlareNote: Identifiable, Equatable {
    var id: UUID
    var dayKey: Int
    var product: String
    var place: String
}
