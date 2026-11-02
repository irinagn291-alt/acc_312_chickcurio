import SwiftUI
import UIKit

struct ContentView: View {
    var board: RoundBoard

    @Environment(\.scenePhase) private var scenePhase
    @State private var today = DayKey.make(from: Date(), calendar: .current)
    @State private var cover: Cover?
    @State private var didReadLaunch = false
    @State private var slowLoad = false

    var body: some View {
        NavigationStack {
            Group {
                if board.isReady == false {
                    TimelineView(
                        board: board,
                        today: today,
                        openNaming: {},
                        openIntake: {},
                        openReport: {},
                        openBodyMap: {}
                    )
                    .redacted(reason: .placeholder)
                    .allowsHitTesting(false)
                    .overlay {
                        if slowLoad {
                            ProgressView()
                                .tint(DesignTokens.ink)
                                .padding(Spacing.s24)
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                        }
                    }
                } else if board.chart.onboardingComplete == false {
                    OnboardingView(board: board) {
                        openReviewIfNeeded()
                    }
                } else if board.isBlank {
                    emptyBoard
                } else {
                    timeline
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DesignTokens.bg)
            .navigationTitle(screenTitle)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar(board.isReady && board.chart.onboardingComplete ? .visible : .hidden, for: .navigationBar)
            .toolbar {
                if board.isReady && board.chart.onboardingComplete {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            cover = .settings
                        } label: {
                            Image(systemName: "gearshape")
                                .frame(minWidth: Spacing.s48, minHeight: Spacing.s48)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(IconHitButtonStyle())
                        .accessibilityLabel("Settings")
                    }
                }
            }
        }
        .sheet(item: $cover) { item in
            NavigationStack {
                sheetBody(item)
                    .navigationTitle(coverTitle(item))
                    .navigationBarTitleDisplayMode(.inline)
                    .navigationBarBackButtonHidden(true)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button {
                                cover = nil
                            } label: {
                                Text("Close")
                                    .font(TypeScale.font(.caption, weight: .bold))
                                    .foregroundStyle(DesignTokens.ink)
                                    .frame(minWidth: Spacing.s48, minHeight: Spacing.s48)
                                    .contentShape(Rectangle())
                            }
                        }
                    }
            }
            .modifier(SheetFade())
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationBackground(DesignTokens.bg)
            .presentationCornerRadius(Radius.card)
        }
        .task {
            try? await Task.sleep(for: .milliseconds(150))
            if board.isReady == false {
                slowLoad = true
            }
        }
        .task {
            if board.isReady == false {
                await board.load()
            }
            openReviewIfNeeded()
        }
        .onChange(of: board.isReady) { _, ready in
            if ready {
                openReviewIfNeeded()
            }
        }
        .onChange(of: board.chart.onboardingComplete) { _, complete in
            if complete {
                openReviewIfNeeded()
            }
        }
        .onAppear { ReviewLaunch.bringForward() }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            today = DayKey.make(from: Date(), calendar: .current)
            ReviewLaunch.bringForward()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            today = DayKey.make(from: Date(), calendar: .current)
        }
    }

    private var timeline: some View {
        TimelineView(
            board: board,
            today: today,
            openNaming: { cover = .naming },
            openIntake: { cover = .intake },
            openReport: { cover = .report },
            openBodyMap: { cover = .bodyMap }
        )
    }

    private var emptyBoard: some View {
        VStack(alignment: .leading, spacing: Spacing.s16) {
            Image("spr_EmptyHome")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .containerRelativeFrame(.vertical, count: 10, span: 4, spacing: Spacing.s16)
                .background(DesignTokens.surface)
                .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                .accessibilityHidden(true)
            Text("The board is empty")
                .font(TypeScale.font(.display, weight: .bold))
                .foregroundStyle(DesignTokens.ink)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)
            Text("Pick a food, then mark today clean or flare.")
                .font(TypeScale.font(.caption))
                .foregroundStyle(DesignTokens.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.s24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .safeAreaInset(edge: .bottom) {
            Button {
                cover = .naming
            } label: {
                Text("Pick a food")
                    .frame(maxWidth: .infinity, minHeight: Spacing.s48)
                    .contentShape(Rectangle())
            }
            .buttonStyle(SoftCardButtonStyle(kind: .accent))
            .padding(Spacing.s24)
            .background(.regularMaterial)
        }
    }

    private var screenTitle: String {
        if board.isReady, let name = board.suspectName, name.isEmpty == false {
            return name
        }
        return "One suspect"
    }

    /// Naming handoff while hunting uses Mark today — unless the naming cover
    /// is demonstrating the pick board (`-ReviewScreen naming`).
    private func coverTitle(_ item: Cover) -> String {
        if item == .naming, board.phase == .hunting, ReviewLaunch.screen != "naming" {
            return "Mark today"
        }
        return item.title
    }

    @ViewBuilder
    private func sheetBody(_ item: Cover) -> some View {
        switch item {
        case .intake:
            IntakeView(board: board, today: today)
        case .report:
            ReportView(board: board)
        case .bodyMap:
            BodyMapView(board: board)
        case .settings:
            SettingsView(board: board, replay: {
                cover = nil
                Task { await board.setOnboardingComplete(false) }
            }, openSources: {
                cover = .sources
            })
        case .sources:
            SourcesView(board: board)
        case .naming:
            NamingView(board: board, today: today, onClose: { cover = nil })
        }
    }

    private func openReviewIfNeeded() {
        guard board.isReady, board.chart.onboardingComplete, didReadLaunch == false else { return }
        didReadLaunch = true
        let key = ReviewLaunch.screen
        let next: Cover?
        switch key {
        case "log", "intake":
            next = .intake
        case "goals", "report":
            next = .report
        case "bodymap":
            next = .bodyMap
        case "settings":
            next = .settings
        case "sources":
            next = .sources
        case "naming":
            next = .naming
        case "today", "timeline", .none:
            next = nil
        default:
            next = nil
        }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            cover = next
        }
        ReviewLaunch.bringForward()
    }
}

private enum Cover: String, Identifiable {
    case intake
    case report
    case bodyMap
    case settings
    case sources
    case naming

    var id: String { rawValue }

    var title: String {
        switch self {
        case .intake:
            return "Food log"
        case .report:
            return "Ledger"
        case .bodyMap:
            return "Places"
        case .settings:
            return "Settings"
        case .sources:
            return "Sources"
        case .naming:
            return "Food name"
        }
    }
}

#Preview {
    ChartSessionHost()
}
