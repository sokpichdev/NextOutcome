import Foundation

/// Pure display formatting for shell chrome (tab balance label, drawer address).
public enum ShellFormat {
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
    public static func balanceLabel(_ value: Decimal?) -> String {
        guard let value, let s = amount.string(from: value as NSDecimalNumber) else { return "$--" }
        return "$" + s
    }

    /// Drawer header address: "0x" + first 8 chars + "…". `nil`/short → "—".
    public static func shortAddress(_ address: String?) -> String {
        guard let address, address.count > 10 else { return "—" }
        return String(address.prefix(10)) + "…"
    }
}
