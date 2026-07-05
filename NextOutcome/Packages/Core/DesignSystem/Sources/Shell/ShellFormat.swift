import Foundation

/// Pure display formatting for shell chrome (tab balance label, drawer address).
///
/// "Shell" here refers to the app's persistent outer UI — the tab bar and side
/// drawer — as opposed to the content inside individual feature screens. These
/// helpers are pure functions (no side effects) so they're easy to unit test and
/// reuse anywhere the balance or wallet address needs to be displayed.
public enum ShellFormat {
    /// A number formatter configured to always show exactly 2 decimal places and
    /// no thousands separators, using a fixed US locale so formatting is
    /// consistent regardless of the device's region settings.
    private static let amount: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "en_US_POSIX")
        f.usesGroupingSeparator = false
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }()

    /// Live balance for the Portfolio tab label, e.g. "$7.02". `nil` → "$--".
    /// - Parameter value: The account balance to display, or `nil` if it hasn't
    ///   loaded yet.
    /// - Returns: A formatted currency string prefixed with `$`, or `"$--"` as a
    ///   placeholder when there's no value to show.
    public static func balanceLabel(_ value: Decimal?) -> String {
        guard let value, let s = amount.string(from: value as NSDecimalNumber) else { return "$--" }
        return "$" + s
    }

    /// Drawer header address: "0x" + first 8 chars + "…". `nil`/short → "—".
    /// - Parameter address: The full wallet address, or `nil` if not connected.
    /// - Returns: A shortened, ellipsized address suitable for display, or `"—"`
    ///   if `address` is `nil` or too short to shorten meaningfully.
    public static func shortAddress(_ address: String?) -> String {
        guard let address, address.count > 10 else { return "—" }
        return String(address.prefix(10)) + "…"
    }
}
