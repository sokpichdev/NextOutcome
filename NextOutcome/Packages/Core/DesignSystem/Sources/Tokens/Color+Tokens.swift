import SwiftUI

public enum DSColor {
    public static let background       = Color(hex: 0x0B0E15)
    public static let surface          = Color(hex: 0x161B27)
    public static let surfaceElevated  = Color(hex: 0x1F2636)
    public static let accent           = Color(hex: 0x3B8AF7)
    public static let accent2          = Color(hex: 0x2D6BF0)
    public static let positive         = Color(hex: 0x2FD27A)
    public static let positive2        = Color(hex: 0x1FB866)
    public static let negative         = Color(hex: 0xFF5E6B)
    public static let negative2        = Color(hex: 0xE8485A)
    public static let textPrimary      = Color(hex: 0xF4F6FB)
    public static let textSecondary    = Color(hex: 0x9AA6BD)
    public static let separator        = Color(hex: 0x262E3D)
    public static let categoryGold     = Color(hex: 0xE5A93C)
    public static let newsOrange       = Color(hex: 0xF26B3A)
    public static let depositNavy      = Color(hex: 0x1E3A8A)
    public static let positiveTint     = positive.opacity(0.15)
    public static let negativeTint     = negative.opacity(0.15)
    public static let accentTint       = accent.opacity(0.16)
    public static let hairline         = Color.white.opacity(0.05)
}

extension Color {
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
    public init?(hexString: String?) {
        guard let raw = hexString?.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "#", with: ""),
              raw.count == 6,
              let value = UInt32(raw, radix: 16)
        else { return nil }
        self.init(hex: value)
    }
}