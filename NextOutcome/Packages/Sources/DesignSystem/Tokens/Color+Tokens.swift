import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// The app's centralized color palette ("design tokens"). Every color used in the
/// UI should come from here instead of being hardcoded inline (e.g. `Color.blue`),
/// so the whole app can be restyled by changing one file.
///
/// Every token below carries separate light and dark values and resolves at draw
/// time against the environment's active appearance. The app forces that
/// appearance everywhere via `.preferredColorScheme(_:)`, driven by
/// `ThemeManager`, rather than following the device's system setting.
public enum DSColor {
    /// The app's base background color.
    public static let background       = dynamic(light: 0xF7F8FB, dark: 0x0B0E15)
    /// A slightly elevated surface color used for cards and panels sitting on top
    /// of the background.
    public static let surface          = dynamic(light: 0xFFFFFF, dark: 0x161B27)
    /// An even more elevated surface, used for elements that should appear
    /// "raised" above a regular surface (e.g. a nested card or a pressed state).
    public static let surfaceElevated  = dynamic(light: 0xEEF1F6, dark: 0x1F2636)
    /// The primary brand accent color (blue), used for buttons, links, and
    /// highlighted/selected UI elements. Unchanged between themes.
    public static let accent           = Color(hex: 0x3B8AF7)
    /// A secondary, slightly deeper blue used alongside `accent` in gradients.
    /// Unchanged between themes.
    public static let accent2          = Color(hex: 0x2D6BF0)
    /// Green used to indicate a positive value (e.g. price up, profit). Darker
    /// in Light mode for contrast against a white background.
    public static let positive         = dynamic(light: 0x1FA262, dark: 0x2FD27A)
    /// A secondary, slightly deeper green used alongside `positive` in gradients.
    public static let positive2        = dynamic(light: 0x178C50, dark: 0x1FB866)
    /// Red used to indicate a negative value (e.g. price down, loss). Darker in
    /// Light mode for contrast against a white background.
    public static let negative         = dynamic(light: 0xE23F4D, dark: 0xFF5E6B)
    /// A secondary, slightly deeper red used alongside `negative` in gradients.
    public static let negative2        = dynamic(light: 0xC93546, dark: 0xE8485A)
    /// The main text color for readable content — near-black on Light, near-white
    /// on Dark.
    public static let textPrimary      = dynamic(light: 0x11151F, dark: 0xF4F6FB)
    /// A dimmer text color for secondary/supporting text (subtitles, captions,
    /// timestamps) that shouldn't compete with primary text.
    public static let textSecondary    = dynamic(light: 0x5B6472, dark: 0x9AA6BD)
    /// A subtle color for dividing lines between sections/rows.
    public static let separator        = dynamic(light: 0xE2E5EB, dark: 0x262E3D)
    /// A gold/amber accent used for special category highlights (e.g. featured
    /// tags). Darker in Light mode for contrast.
    public static let categoryGold     = dynamic(light: 0xB9791F, dark: 0xE5A93C)
    /// An orange accent used specifically for news-related cards/badges. Darker
    /// in Light mode for contrast.
    public static let newsOrange       = dynamic(light: 0xD8551F, dark: 0xF26B3A)
    /// A deep navy used for deposit/funding-related UI elements. Unchanged
    /// between themes.
    public static let depositNavy      = Color(hex: 0x1E3A8A)
    /// A translucent version of `positive`, used as a subtle background tint
    /// behind positive values (e.g. a green pill background).
    public static let positiveTint     = positive.opacity(0.15)
    /// A translucent version of `negative`, used as a subtle background tint
    /// behind negative values.
    public static let negativeTint     = negative.opacity(0.15)
    /// A translucent version of `accent`, used as a subtle background tint behind
    /// selected/highlighted elements.
    public static let accentTint       = accent.opacity(0.16)
    /// A near-invisible hairline for subtle borders/dividers: translucent white
    /// on Dark surfaces, translucent black on Light surfaces.
    public static let hairline         = dynamicHairline()

    /// Builds a `Color` that resolves to `light` in Light mode and `dark` in Dark
    /// mode, tracking the environment's active appearance rather than being fixed
    /// at creation time.
    /// - Parameters:
    ///   - light: 24-bit hex value used in Light mode.
    ///   - dark: 24-bit hex value used in Dark mode.
    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        #if canImport(UIKit)
        return Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(Color(hex: dark)) : UIColor(Color(hex: light))
        })
        #elseif canImport(AppKit)
        return Color(NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(Color(hex: dark)) : NSColor(Color(hex: light))
        })
        #else
        return Color(hex: dark)
        #endif
    }

    /// `hairline` needs different *opacity of a different base color* per
    /// appearance (translucent white reads on dark surfaces, translucent black
    /// on light ones), so it can't share the single-hex-pair `dynamic(light:dark:)`
    /// helper above.
    private static func dynamicHairline() -> Color {
        #if canImport(UIKit)
        return Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor.white.withAlphaComponent(0.05)
                : UIColor.black.withAlphaComponent(0.06)
        })
        #elseif canImport(AppKit)
        return Color(NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor.white.withAlphaComponent(0.05)
                : NSColor.black.withAlphaComponent(0.06)
        })
        #else
        return Color.white.opacity(0.05)
        #endif
    }
}

extension Color {
    /// Creates a `Color` from a packed 24-bit hex value (e.g. `0x3B8AF7`), the way
    /// colors are typically written in design tools/specs.
    /// - Parameters:
    ///   - hex: A 24-bit RGB value, e.g. `0xFF0000` for red.
    ///   - opacity: The alpha value from 0 (transparent) to 1 (opaque). Defaults to 1.
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red:   Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8)  & 0xFF) / 255,
            blue:  Double( hex        & 0xFF) / 255,
            opacity: opacity
        )
    }

    /// Parses a `#RRGGBB` / `RRGGBB` string (e.g. a team brand colour from the sports feed).
    /// Returns nil for anything that isn't six hex digits.
    /// - Parameter hexString: A hex color string, with or without a leading `#`.
    ///   May be `nil`, in which case this initializer also fails.
    public init?(hexString: String?) {
        guard let raw = hexString?.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "#", with: ""),
              raw.count == 6,
              let value = UInt32(raw, radix: 16)
        else { return nil }
        self.init(hex: value)
    }
}
