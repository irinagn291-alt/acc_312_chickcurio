import SwiftUI

/// SPEC section 7. The only place these hex values live — reach colours
/// and the font family through here. Keep this file and its values.
enum DesignTokens {
    /// #FCFCFC
    static let bg = Color(red: 0.988235, green: 0.988235, blue: 0.988235)
    static let bgHex = "#FCFCFC"
    /// #F5F5F5
    static let surface = Color(red: 0.960784, green: 0.960784, blue: 0.960784)
    static let surfaceHex = "#F5F5F5"
    /// #121212
    static let ink = Color(red: 0.070588, green: 0.070588, blue: 0.070588)
    static let inkHex = "#121212"
    /// #2398A9
    static let accent = Color(red: 0.137255, green: 0.596078, blue: 0.662745)
    static let accentHex = "#2398A9"
    /// #575757
    static let muted = Color(red: 0.341176, green: 0.341176, blue: 0.341176)
    static let mutedHex = "#575757"
    static let fontFamily = "Iowan Old Style"
}

/// Base-4 spacing. Views use these and no other padding or gap.
enum Spacing {
    static let s4: CGFloat = 4
    static let s8: CGFloat = 8
    static let s12: CGFloat = 12
    static let s16: CGFloat = 16
    static let s20: CGFloat = 20
    static let s24: CGFloat = 24
    static let s32: CGFloat = 32
    static let s40: CGFloat = 40
    static let s48: CGFloat = 48
}

/// Section 7.4. Cards and sheets use `card`. Chips and small controls use `chip`.
enum Radius {
    static let card: CGFloat = 16
    static let chip: CGFloat = 2
}

/// Six steps, one family. Home stays on display and caption.
enum TypeScale {
    enum Step {
        case display
        case title
        case headline
        case body
        case callout
        case caption
    }

    /// Body step in points. The navigation bar uses this same value.
    static let bodyPoint: CGFloat = 17

    static func font(_ step: Step, weight: Font.Weight = .regular) -> Font {
        let size: CGFloat
        let relative: Font.TextStyle
        switch step {
        case .display:
            size = 40
            relative = .largeTitle
        case .title:
            size = 28
            relative = .title
        case .headline:
            size = 22
            relative = .headline
        case .body:
            size = bodyPoint
            relative = .body
        case .callout:
            size = 16
            relative = .callout
        case .caption:
            size = 13
            relative = .caption
        }
        return Font.custom(DesignTokens.fontFamily, size: size, relativeTo: relative).weight(weight)
    }
}

/// Press and sheet use the snap ease-out. Counts use the shared spring.
enum Motion {
    static let press = Animation.easeOut(duration: 0.16)
    static let sheet = Animation.easeOut(duration: 0.17)
    static let stateChange = Animation.spring(.snappy)
}
