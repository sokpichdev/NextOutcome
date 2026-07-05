import SwiftUI

/// The app's centralized color palette ("design tokens"). Every color used in the
/// UI should come from here instead of being hardcoded inline (e.g. `Color.blue`),
/// so the whole app can be restyled by changing one file.
///
/// All colors are defined from a dark, near-black base since the app uses a dark
/// theme throughout (see `DSColor.background`).
public enum DSColor {
    /// The app's base background color — a very dark near-black navy.
    public static let background       = Color(hex: 0x0B0E15)
    /// A slightly lighter surface color used for cards and panels sitting on top
    /// of the background.
    public static let surface          = Color(hex: 0x161B27)
    /// An even lighter surface, used for elements that should appear "raised"
    /// above a regular surface (e.g. a nested card or a pressed state).
    public static let surfaceElevated  = Color(hex: 0x1F2636)
    /// The primary brand accent color (blue), used for buttons, links, and
    /// highlighted/selected UI elements.
    public static let accent           = Color(hex: 0x3B8AF7)
    /// A secondary, slightly deeper blue used alongside `accent` in gradients.
    public static let accent2          = Color(hex: 0x2D6BF0)
    /// Green used to indicate a positive value (e.g. price up, profit).
    public static let positive         = Color(hex: 0x2FD27A)
    /// A secondary, slightly deeper green used alongside `positive` in gradients.
    public static let positive2        = Color(hex: 0x1FB866)
    /// Red used to indicate a negative value (e.g. price down, loss).
    public static let negative         = Color(hex: 0xFF5E6B)
    /// A secondary, slightly deeper red used alongside `negative` in gradients.
    public static let negative2        = Color(hex: 0xE8485A)
    /// The main text color for readable content on dark backgrounds — near-white.
    public static let textPrimary      = Color(hex: 0xF4F6FB)
    /// A dimmer text color for secondary/supporting text (subtitles, captions,
    /// timestamps) that shouldn't compete with primary text.
    public static let textSecondary    = Color(hex: 0x9AA6BD)
    /// A subtle color for dividing lines between sections/rows.
    public static let separator        = Color(hex: 0x262E3D)
    /// A gold/amber accent used for special category highlights (e.g. featured tags).
    public static let categoryGold     = Color(hex: 0xE5A93C)
    /// An orange accent used specifically for news-related cards/badges.
    public static let newsOrange       = Color(hex: 0xF26B3A)
    /// A deep navy used for deposit/funding-related UI elements.
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
    /// A near-invisible white used for very subtle hairline borders/dividers on
    /// dark surfaces.
    public static let hairline         = Color.white.opacity(0.05)
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