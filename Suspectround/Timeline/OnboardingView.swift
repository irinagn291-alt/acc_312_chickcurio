import SwiftUI

struct OnboardingView: View {
    var board: RoundBoard
    var onDone: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var page = 0

    private let pages: [(art: String, title: String, line: String)] = [
        ("spr_Onboarding1", "Test one food at a time.", "Mark each day clean or flare."),
        ("spr_Onboarding2", "Mark the open day.", "Clean keeps the week going. Flare stops it."),
        ("spr_Onboarding3", "Seven clean days clear it.", "A flare busts it. Then rotate off.")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s16) {
            art
            Text(pages[page].title)
                .font(TypeScale.font(.display, weight: .bold))
                .foregroundStyle(DesignTokens.ink)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)
            Text(pages[page].line)
                .font(TypeScale.font(.body))
                .foregroundStyle(DesignTokens.muted)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: Spacing.s8) {
                Text(page + 1, format: .number.precision(.fractionLength(0)))
                Text("of")
                Text(pages.count, format: .number.precision(.fractionLength(0)))
            }
            .font(TypeScale.font(.caption, weight: .bold))
            .foregroundStyle(DesignTokens.ink)
            .accessibilityElement(children: .combine)
            pageDots
        }
        .padding(Spacing.s24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(DesignTokens.bg)
        .safeAreaInset(edge: .bottom) {
            controls
        }
        .animation(reduceMotion ? Motion.press : Motion.press, value: page)
    }

    private var art: some View {
        Image(pages[page].art)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity)
            .containerRelativeFrame(.vertical, count: 10, span: 4, spacing: Spacing.s16)
            .background(DesignTokens.surface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .accessibilityHidden(true)
    }

    private var pageDots: some View {
        HStack(spacing: Spacing.s8) {
            ForEach(pages.indices, id: \.self) { index in
                RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
                    .fill(index == page ? DesignTokens.accent : DesignTokens.muted)
                    .frame(width: Spacing.s24, height: Spacing.s8)
                    .accessibilityHidden(true)
            }
        }
    }

    private var controls: some View {
        VStack(spacing: Spacing.s8) {
            Button("Skip") { finish() }
                .buttonStyle(SoftCardButtonStyle(kind: .quiet))
                .disabled(board.isBusy)
            Button(page == pages.count - 1 ? "Start" : "Continue") {
                if page == pages.count - 1 {
                    finish()
                } else {
                    page += 1
                }
            }
            .buttonStyle(SoftCardButtonStyle(kind: .accent))
            .disabled(board.isBusy)
        }
        .padding(Spacing.s24)
        .background(.regularMaterial)
    }

    private func finish() {
        Task {
            await board.setOnboardingComplete(true)
            onDone()
        }
    }
}
