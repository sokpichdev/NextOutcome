//
//  MarketFormatting.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import Foundation

/// Display helpers. domain values stay `Decimal`; `Double` appears only here, at the formatting edge.
public enum MarketFormatting {

    /// 0…1 price → whole-percent string. 0.62 → "62%".
    public static func percent(_ price: Decimal) -> String {
        let clamped = min(max(price, 0), 1)
        let value = NSDecimalNumber(decimal: clamped * 100).doubleValue
        return "\(Int(value.rounded()))%"
    }

    /// 0…1 price → one-decimal cents string. 0.334 → "33.4¢".
    public static func cents(_ price: Decimal) -> String {
        let clamped = min(max(price, 0), 1)
        let value = NSDecimalNumber(decimal: clamped * 100).doubleValue
        return String(format: "%.1f¢", value)
    }

    /// 0…1 price → Double fraction for `ProbabilityBar`.
    public static func fraction(_ price: Decimal) -> Double {
        let clamped = min(max(price, 0), 1)
        return NSDecimalNumber(decimal: clamped).doubleValue
    }

    /// Compact USD. 3_200_000_000 → "$3.2B", 122_000_000 → "$122M".
    public static func compactUSD(_ amount: Decimal) -> String {
        let value = NSDecimalNumber(decimal: amount).doubleValue
        let sign = value < 0 ? "-" : ""
        let magnitude = Swift.abs(value)
        switch magnitude {
        case 1_000_000_000...:
            return "\(sign)$\(trimmed(magnitude / 1_000_000_000))B"
        case 1_000_000...:
            return "\(sign)$\(trimmed(magnitude / 1_000_000))M"
        case 1_000...:
            return "\(sign)$\(trimmed(magnitude / 1_000))K"
        default:
            return "\(sign)$\(Int(magnitude))"
        }
    }

    /// Relative countdown. Future → "Ends in 20d" / "Ends in 4h"; past → "Ended"; nil → nil.
    public static func countdown(to date: Date?, now: Date = Date()) -> String? {
        guard let date else { return nil }
        let interval = date.timeIntervalSince(now)
        guard interval > 0 else { return "Ended" }
        let days = Int(interval / 86_400)
        if days >= 1 { return "Ends in \(days)d" }
        let hours = Int(interval / 3_600)
        if hours >= 1 { return "Ends in \(hours)h" }
        let minutes = Int(interval / 60)
        return "Ends in \(minutes)m"
    }

    /// One decimal, trailing ".0" removed. 3.0 → "3", 3.2 → "3.2".
    private static func trimmed(_ v: Double) -> String {
        let s = String(format: "%.1f", v)
        return s.hasSuffix(".0") ? String(s.dropLast(2)) : s
    }
}
