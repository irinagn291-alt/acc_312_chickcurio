import SwiftUI

struct SettingsView: View {
    var board: RoundBoard
    var replay: () -> Void
    var openSources: () -> Void

    @State private var confirmErase = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.s16) {
                if let loadError = board.loadError {
                    StatusBanner(title: loadError) {
                        Task { await board.load() }
                    }
                }
                VStack(alignment: .leading, spacing: Spacing.s8) {
                    Text(board.chart.sessions.isEmpty ? "Diary is empty." : "Marks are on this device.")
                        .font(TypeScale.font(.display, weight: .bold))
                        .foregroundStyle(DesignTokens.ink)
                        .lineLimit(4)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Replay the intro, erase the diary, or open contact.")
                        .font(TypeScale.font(.body))
                        .foregroundStyle(DesignTokens.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Button(action: replay) {
                    Text("Replay intro")
                        .frame(maxWidth: .infinity, minHeight: Spacing.s48)
                        .contentShape(Rectangle())
                }
                .buttonStyle(SoftCardButtonStyle(kind: .quiet))
                .disabled(board.isBusy)
                Button(action: openSources) {
                    Text("Cited notes")
                        .frame(maxWidth: .infinity, minHeight: Spacing.s48)
                        .contentShape(Rectangle())
                }
                .buttonStyle(SoftCardButtonStyle(kind: .quiet))
                Link(destination: URL(string: "https://suspectround-hunt.site/contact-us")!) {
                    Label("Contact", systemImage: "arrow.up.right")
                        .frame(maxWidth: .infinity, minHeight: Spacing.s48)
                        .contentShape(Rectangle())
                }
                .buttonStyle(SoftCardButtonStyle(kind: .quiet))
                Button {
                    confirmErase = true
                } label: {
                    Text("Erase diary")
                        .frame(maxWidth: .infinity, minHeight: Spacing.s48)
                        .contentShape(Rectangle())
                }
                .buttonStyle(SoftCardButtonStyle(kind: .destructive))
                .disabled(board.isBusy)
            }
            .padding(Spacing.s24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(DesignTokens.bg)
        .confirmationDialog(
            "Erase the diary? Every mark on this device goes with it.",
            isPresented: $confirmErase,
            titleVisibility: .visible
        ) {
            Button("Erase diary", role: .destructive) {
                Task { await board.resetAllData() }
            }
            Button("Close", role: .cancel) {}
        }
    }
}
