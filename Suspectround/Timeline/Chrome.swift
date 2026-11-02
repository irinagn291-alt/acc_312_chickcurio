import SwiftUI
import UIKit

enum BarTitle {
    @MainActor
    static func apply() {
        let font = UIFont(name: DesignTokens.fontFamily, size: TypeScale.bodyPoint)
            ?? UIFont.preferredFont(forTextStyle: .body)
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(DesignTokens.bg)
        appearance.shadowColor = UIColor(DesignTokens.bg)
        appearance.titleTextAttributes = [
            .foregroundColor: UIColor(DesignTokens.ink),
            .font: font
        ]
        let bar = UINavigationBar.appearance()
        bar.standardAppearance = appearance
        bar.scrollEdgeAppearance = appearance
        bar.compactAppearance = appearance
    }
}

struct SoftCardButtonStyle: ButtonStyle {
    enum Kind {
        case accent
        case quiet
        case destructive
    }

    var kind: Kind = .accent
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(TypeScale.font(.caption, weight: .bold))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, minHeight: Spacing.s48)
            .padding(.horizontal, Spacing.s16)
            .background(fill, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .scaleEffect(reduceMotion || configuration.isPressed == false || isEnabled == false ? 1 : 0.97)
            .opacity(configuration.isPressed && reduceMotion ? 0.72 : 1)
            .animation(Motion.press, value: configuration.isPressed)
    }

    private var foreground: Color {
        switch kind {
        case .accent, .quiet:
            return DesignTokens.ink
        case .destructive:
            return isEnabled ? DesignTokens.bg : DesignTokens.ink
        }
    }

    private var fill: Color {
        guard isEnabled else { return DesignTokens.surface }
        switch kind {
        case .accent:
            return DesignTokens.accent
        case .quiet:
            return DesignTokens.surface
        case .destructive:
            return DesignTokens.ink
        }
    }
}

struct ScaleOnlyButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .scaleEffect(reduceMotion || configuration.isPressed == false || isEnabled == false ? 1 : 0.97)
            .opacity(configuration.isPressed && reduceMotion ? 0.72 : 1)
            .animation(Motion.press, value: configuration.isPressed)
    }
}

struct IconHitButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(TypeScale.font(.caption, weight: .bold))
            .foregroundStyle(isEnabled ? DesignTokens.ink : DesignTokens.muted)
            .frame(minWidth: Spacing.s48, minHeight: Spacing.s48)
            .background(DesignTokens.surface, in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
            .scaleEffect(reduceMotion || configuration.isPressed == false ? 1 : 0.97)
            .opacity(configuration.isPressed && reduceMotion ? 0.72 : 1)
            .animation(Motion.press, value: configuration.isPressed)
    }
}

struct SheetFade: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    /// `-ReviewScreen` freezes UIKit animations; never start the cover at opacity 0.
    private var reviewShot: Bool {
        ProcessInfo.processInfo.arguments.contains(ReviewLaunch.argument)
    }

    func body(content: Content) -> some View {
        content
            .opacity(shown || reviewShot ? 1 : 0)
            .scaleEffect(reduceMotion || reviewShot || shown ? 1 : 0.96)
            .onAppear {
                if reduceMotion || reviewShot {
                    shown = true
                } else {
                    withAnimation(Motion.sheet) { shown = true }
                }
                ReviewLaunch.bringForward()
            }
    }
}

struct StatusBanner: View {
    var title: String
    var retry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s8) {
            Label(title, systemImage: "exclamationmark.triangle")
                .font(TypeScale.font(.body))
                .foregroundStyle(DesignTokens.ink)
                .fixedSize(horizontal: false, vertical: true)
            Button("Try again", action: retry)
                .buttonStyle(SoftCardButtonStyle(kind: .quiet))
        }
        .padding(Spacing.s16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }
}

func refusalCopy(_ refusal: RoundRefusal?) -> String? {
    switch refusal {
    case nil:
        return nil
    case .markOnIdle:
        return "No food is on trial. Pick a food first."
    case .markOnBusted:
        return "Busted. Rotate, then mark a new day."
    case .markOnCleared:
        return "Cleared. Pick the next food."
    case .secondPick:
        return "Already hunting. Mark today instead."
    case .pickWhileBusted:
        return "Busted. Rotate before a new food."
    case .repeatsLastBust:
        return "That food just failed. Pick a different one."
    case .invalidDay:
        return "Day is not valid. Try again."
    case .duplicateDay:
        return "Day already marked. Leave it."
    case .rotateWhileNotBusted:
        return "Rotate waits for a bust."
    case .emptyName:
        return "Name is empty. Type a food."
    case .intakeRefused:
        return "Log failed. A hunt has to be open."
    }
}
