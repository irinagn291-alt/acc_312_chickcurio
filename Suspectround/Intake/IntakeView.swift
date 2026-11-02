import SwiftUI

struct IntakeView: View {
    var board: RoundBoard
    var today: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var focus: Field?
    @State private var draft = NameDraft()
    @State private var touched = false

    private enum Field: Hashable {
        case name
    }

    /// Space for the pinned Save food bar so shelf chips never sit under it.
    private var saveBarClearance: CGFloat {
        Spacing.s48 + Spacing.s24 * 2 + Spacing.s16
    }

    var body: some View {
        @Bindable var draft = draft
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s16) {
                    if let loadError = board.loadError {
                        StatusBanner(title: loadError) {
                            Task { await board.load() }
                        }
                    }
                    Text("Name the food you ate")
                        .font(TypeScale.font(.display, weight: .bold))
                        .foregroundStyle(DesignTokens.ink)
                        .lineLimit(4)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Add it on the open day. No calorie count.")
                        .font(TypeScale.font(.body))
                        .foregroundStyle(DesignTokens.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    TextField("Food name", text: $draft.text)
                        .font(TypeScale.font(.body))
                        .foregroundStyle(DesignTokens.ink)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .focused($focus, equals: .name)
                        .padding(Spacing.s16)
                        .frame(minHeight: Spacing.s48)
                        .background(DesignTokens.surface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                        .id(Field.name)
                        .onSubmit(save)
                        .onChange(of: draft.text) { _, _ in
                            draft.schedule()
                        }
                    if touched && trimmed.isEmpty {
                        Text("Name is empty. Type a food.")
                            .font(TypeScale.font(.caption))
                            .foregroundStyle(DesignTokens.ink)
                    }
                    if let copy = refusalCopy(board.refusal) {
                        Text(copy)
                            .font(TypeScale.font(.body))
                            .foregroundStyle(DesignTokens.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let note = draft.note {
                        Text(note)
                            .font(TypeScale.font(.body))
                            .foregroundStyle(DesignTokens.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if draft.hits.isEmpty == false {
                        ForEach(draft.hits, id: \.self) { name in
                            Button {
                                draft.text = name
                                save()
                            } label: {
                                Text(name)
                                    .foregroundStyle(DesignTokens.ink)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .frame(maxWidth: .infinity, minHeight: Spacing.s48, alignment: .leading)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(SoftCardButtonStyle(kind: .quiet))
                            .disabled(board.isBusy)
                        }
                    }
                    shelfList
                    foodList
                    HuntCapture { code in
                        draft.apply(code: code)
                    }
                }
                .padding(Spacing.s24)
                .padding(.bottom, saveBarClearance)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: focus) { _, value in
                guard let value else { return }
                if reduceMotion {
                    proxy.scrollTo(value, anchor: .center)
                } else {
                    withAnimation(Motion.stateChange) {
                        proxy.scrollTo(value, anchor: .center)
                    }
                }
            }
        }
        .background(DesignTokens.bg)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Button("Close") { focus = nil }
                    .frame(minWidth: Spacing.s48, minHeight: Spacing.s48)
            }
        }
        .simultaneousGesture(TapGesture().onEnded { focus = nil })
        .safeAreaInset(edge: .bottom) {
            Button(action: save) {
                ZStack {
                    Text("Save food")
                        .opacity(board.isBusy ? 0 : 1)
                    if board.isBusy {
                        ProgressView().tint(DesignTokens.ink)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: Spacing.s48)
                .contentShape(Rectangle())
            }
            .buttonStyle(SoftCardButtonStyle(kind: canSave ? .accent : .quiet))
            .disabled(board.isBusy || canSave == false)
            .padding(Spacing.s24)
            .background(DesignTokens.bg)
        }
    }

    private var trimmed: String {
        draft.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        trimmed.isEmpty == false
    }

    private var shelfList: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: Spacing.s8),
                GridItem(.flexible(), spacing: Spacing.s8)
            ],
            spacing: Spacing.s8
        ) {
            ForEach(FoodShelf.names(books: board.chart.books.map(\.name)), id: \.self) { name in
                Button {
                    draft.text = name
                    log(name)
                } label: {
                    Text(name)
                        .foregroundStyle(DesignTokens.ink)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, minHeight: Spacing.s48)
                        .contentShape(Rectangle())
                }
                .buttonStyle(SoftCardButtonStyle(kind: .quiet))
                .disabled(board.isBusy)
            }
        }
    }

    @ViewBuilder
    private var foodList: some View {
        VStack(alignment: .leading, spacing: Spacing.s8) {
            if logged.isEmpty {
                Text("Nothing logged on this day yet.")
                    .font(TypeScale.font(.body))
                    .foregroundStyle(DesignTokens.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, minHeight: Spacing.s48, alignment: .leading)
            } else {
                ForEach(logged) { item in
                    HStack(spacing: Spacing.s8) {
                        Text(item.name)
                            .font(TypeScale.font(.body, weight: .bold))
                            .foregroundStyle(DesignTokens.ink)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if let date = DayKey.date(from: item.dayKey, calendar: .current) {
                            Text(date, format: .dateTime.month(.abbreviated).day())
                                .font(TypeScale.font(.caption))
                                .foregroundStyle(DesignTokens.muted)
                                .layoutPriority(1)
                        } else {
                            Text("unknown")
                                .font(TypeScale.font(.caption))
                                .foregroundStyle(DesignTokens.muted)
                                .layoutPriority(1)
                        }
                    }
                    .frame(minHeight: Spacing.s48)
                }
            }
        }
        .padding(Spacing.s16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignTokens.surface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }

    private var logged: [Intake] {
        board.chart.sessions
            .flatMap(\.intakes)
            .sorted { $0.dayKey > $1.dayKey }
    }

    private func save() {
        touched = true
        focus = nil
        guard trimmed.isEmpty == false else { return }
        Task {
            let resolved = await draft.resolveForCommit()
            guard resolved.isEmpty == false else { return }
            log(resolved)
        }
    }

    private func log(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return }
        Task {
            await board.logIntake(name: trimmed, dayKey: today)
            if board.refusal == nil {
                draft.text = ""
                draft.hits = []
                draft.note = nil
                touched = false
            }
        }
    }
}
