import SwiftUI

struct NamingView: View {
    var board: RoundBoard
    var today: Int
    var onClose: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var focus: Field?
    @State private var draft = NameDraft()
    @State private var touched = false

    private enum Field: Hashable {
        case name
    }

    private var hunting: Bool {
        board.phase == .hunting
    }

    /// `-ReviewScreen naming` must show the pick board (field, shelf, scan).
    private var namingCover: Bool {
        ReviewLaunch.screen == "naming"
    }

    /// Real hunting chip tap → Mark today handoff. Naming cover → pick board.
    private var showHuntingHandoff: Bool {
        hunting && namingCover == false
    }

    private var namedDraft: Bool {
        draft.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    /// Accent Save when a name is typed. Naming cover may still refuse a second pick.
    private var pickCommitReady: Bool {
        board.isBusy == false && namedDraft
    }

    /// Space for the pinned bottom bar so chip labels never sit under it.
    private var bottomClearance: CGFloat {
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
                    if showHuntingHandoff {
                        huntingBoard
                    } else {
                        pickBoard
                    }
                }
                .padding(Spacing.s24)
                .padding(.bottom, bottomClearance)
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
        .onAppear {
            // Cover shots must not raise the keyboard scene — landscape + a
            // zero-size keyboard host leaves SpringBoard in the framebuffer.
            if ProcessInfo.processInfo.arguments.contains(ReviewLaunch.argument) {
                focus = nil
            }
            ReviewLaunch.bringForward()
        }
        .navigationTitle(showHuntingHandoff ? "Mark today" : "Food name")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            if showHuntingHandoff {
                Button(action: onClose) {
                    Text("Mark today")
                        .frame(maxWidth: .infinity, minHeight: Spacing.s48)
                        .contentShape(Rectangle())
                }
                .buttonStyle(SoftCardButtonStyle(kind: .accent))
                .disabled(board.isBusy)
                .padding(Spacing.s24)
                .background(DesignTokens.bg)
            } else {
                Button(action: save) {
                    Text("Save food")
                        .frame(maxWidth: .infinity, minHeight: Spacing.s48)
                        .contentShape(Rectangle())
                }
                .buttonStyle(SoftCardButtonStyle(kind: pickCommitReady ? .accent : .quiet))
                .disabled(pickCommitReady == false)
                .padding(Spacing.s24)
                .background(DesignTokens.bg)
            }
        }
    }

    /// Hunt already open — one Mark today page: job, suspect, clean streak, single CTA.
    private var huntingBoard: some View {
        VStack(alignment: .leading, spacing: Spacing.s16) {
            Image("spr_HuntSprite")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .containerRelativeFrame(.vertical, count: 10, span: 3, spacing: Spacing.s16)
                .background(DesignTokens.surface)
                .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                .accessibilityHidden(true)
            Text("Mark today clean or flare.")
                .font(TypeScale.font(.display, weight: .bold))
                .foregroundStyle(DesignTokens.ink)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)
            Text(board.suspectName ?? "One food is on trial.")
                .font(TypeScale.font(.title, weight: .bold))
                .foregroundStyle(DesignTokens.ink)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
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
            .padding(Spacing.s16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DesignTokens.surface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            Text("Seven clean days clears this food. A flare busts it.")
                .font(TypeScale.font(.body))
                .foregroundStyle(DesignTokens.ink)
                .fixedSize(horizontal: false, vertical: true)
            if board.refusal != .secondPick, let copy = refusalCopy(board.refusal) {
                Text(copy)
                    .font(TypeScale.font(.body))
                    .foregroundStyle(DesignTokens.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var pickBoard: some View {
        VStack(alignment: .leading, spacing: Spacing.s16) {
            HuntCapture { code in
                draft.apply(code: code)
            }
            if board.refusal != .secondPick, let copy = refusalCopy(board.refusal) {
                Text(copy)
                    .font(TypeScale.font(.body))
                    .foregroundStyle(DesignTokens.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text("Name the food on trial")
                .font(TypeScale.font(.title, weight: .bold))
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
            if touched && draft.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("Name is empty. Type a food.")
                    .font(TypeScale.font(.caption))
                    .foregroundStyle(DesignTokens.ink)
            }
            if let note = draft.note {
                Text(note)
                    .font(TypeScale.font(.body))
                    .foregroundStyle(DesignTokens.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if draft.hits.isEmpty == false {
                hitList
            }
            chipGrid
        }
    }

    private var shelf: [String] {
        FoodShelf.names(books: board.chart.books.map(\.name))
    }

    private var chipGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: Spacing.s8),
                GridItem(.flexible(), spacing: Spacing.s8)
            ],
            spacing: Spacing.s8
        ) {
            ForEach(shelf, id: \.self) { name in
                Button(action: { pick(name) }) {
                    Text(name)
                        .foregroundStyle(DesignTokens.ink)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, minHeight: Spacing.s48)
                        .contentShape(Rectangle())
                }
                .buttonStyle(SoftCardButtonStyle(kind: .quiet))
                .disabled(board.isBusy || blocked(name))
            }
        }
    }

    private var hitList: some View {
        VStack(alignment: .leading, spacing: Spacing.s8) {
            ForEach(draft.hits, id: \.self) { name in
                Button(action: { pick(name) }) {
                    Text(name)
                        .foregroundStyle(DesignTokens.ink)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, minHeight: Spacing.s48, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(SoftCardButtonStyle(kind: .accent))
                .disabled(board.isBusy || blocked(name))
            }
        }
    }

    private func blocked(_ name: String) -> Bool {
        guard let ban = board.chart.bannedSuspectName else { return false }
        return ban.caseInsensitiveCompare(name) == .orderedSame
    }

    private func pick(_ name: String) {
        touched = true
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return }
        Task {
            await board.pick(name: trimmed, dayKey: today)
            if board.refusal == nil {
                onClose()
            }
        }
    }

    private func save() {
        focus = nil
        touched = true
        let typed = draft.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard typed.isEmpty == false else { return }
        if hunting {
            // Naming cover can show the pick board during a hunt; Save still
            // cannot write a second pick — send them to Mark today instead.
            onClose()
            return
        }
        Task {
            let resolved = await draft.resolveForCommit()
            guard resolved.isEmpty == false else { return }
            pick(resolved)
        }
    }
}
