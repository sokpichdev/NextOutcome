//
//  PortfolioFormatting.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import Foundation

/// Display helpers. Domain values stay `Decimal`; `Double` appears only here.
enum PortfolioFormatting {
    static func usd(_ amount: Decimal) -> String {
        let value = NSDecimalNumber(decimal: amount).doubleValue
        return "$" + String(format: "%.2f", value)
    }

    static func signedUSD(_ amount: Decimal) -> String {
        let value = NSDecimalNumber(decimal: amount).doubleValue
        let sign = value >= 0 ? "+" : "-"
        return sign + "$" + String(format: "%.2f", Swift.abs(value))
    }

    static func signedPercent(_ percent: Decimal) -> String {
        let value = NSDecimalNumber(decimal: percent).doubleValue
        let sign = value >= 0 ? "+" : ""
        return sign + String(format: "%.1f%%", value)
    }

    static func shares(_ size: Decimal) -> String {
        let value = NSDecimalNumber(decimal: size).doubleValue
        return String(format: "%.1f", value)
    }
}
