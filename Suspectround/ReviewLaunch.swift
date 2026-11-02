import Foundation
#if os(iOS)
import UIKit
#endif

/// Live screenshot driver: `-ReviewScreen today|log|goals` (plus extra cover keys).
/// Read `ReviewLaunch.screen` once, after onboarding is done, and open that
/// screen. Keep this file; the navigation it drives belongs to the app.
enum ReviewLaunch {
    static let argument = "-ReviewScreen"

    /// The key after `-ReviewScreen`, or nil on a normal launch.
    /// Call only after onboarding is done — ContentView reads this once.
    static var screen: String? {
        screen(in: ProcessInfo.processInfo.arguments)
    }

    /// Parses launch arguments. `ReviewLaunch.screen` reads this once after onboarding.
    static func screen(in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: argument), index + 1 < arguments.count else {
            return nil
        }
        let key = arguments[index + 1]
        return key.isEmpty ? nil : key
    }

    /// Cover launches pass `-ReviewScreen`. Freeze UIKit transitions so the
    /// screenshot is the destination, not a mid-animation. No-op on watchOS.
    static func disableAnimationsIfNeeded() {
        #if os(iOS)
        if ProcessInfo.processInfo.arguments.contains(argument) {
            UIView.setAnimationsEnabled(false)
        }
        #endif
    }

    /// Simulator only. A restored scene can stay portrait while the device is
    /// landscape, which leaves SpringBoard in the framebuffer. Size the window
    /// to the screen and make it key. Does not read launch arguments.
    @MainActor
    static func bringForward() {
        #if os(iOS) && targetEnvironment(simulator)
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        for scene in scenes {
            let bounds = scene.screen.bounds
            let mask: UIInterfaceOrientationMask
            switch UIDevice.current.orientation {
            case .landscapeLeft:
                mask = .landscapeLeft
            case .landscapeRight:
                mask = .landscapeRight
            case .portraitUpsideDown:
                mask = .portraitUpsideDown
            case .portrait:
                mask = .portrait
            default:
                mask = bounds.width > bounds.height ? .landscapeLeft : .portrait
            }
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { _ in }
            let windows = scene.windows
            let window = windows.first(where: \.isKeyWindow) ?? windows.first
            guard let window else { continue }
            window.frame = bounds
            window.backgroundColor = UIColor(red: 0.988235, green: 0.988235, blue: 0.988235, alpha: 1)
            window.isOpaque = true
            window.makeKeyAndVisible()
        }
        #endif
    }
}

#if os(iOS)
final class ReviewHost: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        #if targetEnvironment(simulator)
        NotificationCenter.default.addObserver(
            forName: UIScene.didActivateNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                ReviewLaunch.bringForward()
            }
        }
        Task { @MainActor in
            ReviewLaunch.bringForward()
        }
        #endif
        return true
    }
}
#endif
