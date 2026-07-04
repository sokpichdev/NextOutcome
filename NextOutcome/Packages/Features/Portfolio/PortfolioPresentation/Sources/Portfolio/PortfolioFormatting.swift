//
//  PortfolioFormatting.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import Foundation

/// Display helpers. Domain values stay `Decimal`; `Double` appears only here.
enum PortfolioFormatting {
    /// Formats a dollar amount as `$12.34`.
    static func usd(_ amount: Decimal) -> String {
        let value = NSDecimalNumber(decimal: amount).doubleValue
        return "$" + String(format: "%.2f", value)
    }

    /// Formats a signed dollar amount as `+$12.34` / `-$12.34` (for PnL).
    static func signedUSD(_ amount: Decimal) -> String {
        let value = NSDecimalNumber(decimal: amount).doubleValue
        let sign = value >= 0 ? "+" : "-"
        return sign + "$" + String(format: "%.2f", Swift.abs(value))
    }

    /// Formats a signed percentage as `+12.3%` / `-12.3%` (for PnL).
    static func signedPercent(_ percent: Decimal) -> String {
        let value = NSDecimalNumber(decimal: percent).doubleValue
        let sign = value >= 0 ? "+" : ""
        return sign + String(format: "%.1f%%", value)
    }

    /// Formats a share count to one decimal place.
    static func shares(_ size: Decimal) -> String {
        let value = NSDecimalNumber(decimal: size).doubleValue
        return String(format: "%.1f", value)
    }
}
