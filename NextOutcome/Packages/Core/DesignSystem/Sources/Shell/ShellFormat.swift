import Foundation

/// Pure display formatting for shell chrome (tab balance label, drawer address).
public enum ShellFormat {
    private static let currency: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.currencySymbol = "$"
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }()

    /// Live balance for the Portfolio tab label, e.g. "$7.02". `nil` → "$--".
    public static func balanceLabel(_ value: Decimal?) -> String {
        guard let value else { return "$--" }
        return currency.string(from: value as NSDecimalNumber) ?? "$--"
    }

    /// Drawer header address: "0x" + first 8 chars + "…". `nil`/short → "—".
    public static func shortAddress(_ address: String?) -> String {
        guard let address, address.count > 10 else { return "—" }
        return String(address.prefix(10)) + "…"
    }
}
