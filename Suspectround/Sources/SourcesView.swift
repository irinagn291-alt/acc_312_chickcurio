import SwiftUI

struct SourcesView: View {
    var board: RoundBoard

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.s16) {
                if let loadError = board.loadError {
                    StatusBanner(title: loadError) {
                        Task { await board.load() }
                    }
                }
                Text("Check the health notes")
                    .font(TypeScale.font(.display, weight: .bold))
                    .foregroundStyle(DesignTokens.ink)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
                Text("A flare note is a personal log, not a diagnosis. Read a source before you treat it as health advice.")
                    .font(TypeScale.font(.body))
                    .foregroundStyle(DesignTokens.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Link(destination: URL(string: "https://www.nhs.uk/conditions/food-intolerance/")!) {
                    Label("NHS food intolerance", systemImage: "arrow.up.right")
                        .frame(maxWidth: .infinity, minHeight: Spacing.s48, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(SoftCardButtonStyle(kind: .quiet))
                Link(destination: URL(string: "https://medlineplus.gov/foodallergy.html")!) {
                    Label("MedlinePlus food allergy", systemImage: "arrow.up.right")
                        .frame(maxWidth: .infinity, minHeight: Spacing.s48, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(SoftCardButtonStyle(kind: .quiet))
            }
            .padding(Spacing.s24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .background(DesignTokens.bg)
    }
}
