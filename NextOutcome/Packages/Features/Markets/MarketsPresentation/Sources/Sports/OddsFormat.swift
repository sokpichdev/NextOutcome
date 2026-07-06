//
//  OddsFormat.swift
//  NextOutcome
//
//  Created by Sok Pich on 06/07/2026.
//

import Foundation

/// How a Sports hub price button displays a market's implied probability, chosen via the
/// hub's Odds Format menu. All conversions are derived from the decimal odds `D = 1/p`.
public enum OddsFormat: String, CaseIterable, Sendable {
    /// The app's usual whole-cent price, e.g. "62¢" (the default).
    case price
    case american
    case decimal
    case fractional
    case percentage
    case indonesian
    case hongKong
    case malaysian

    /// The label shown in the Odds Format menu.
    public var title: String {
        switch self {
        case .price:      return "Price"
        case .american:   return "American"
        case .decimal:    return "Decimal"
        case .fractional: return "Fractional"
        case .percentage: return "Percentage"
        case .indonesian: return "Indonesian"
        case .hongKong:   return "Hong Kong"
        case .malaysian:  return "Malaysian"
        }
    }

    /// Formats a 0…1 implied-probability price in this format. Out-of-range prices are
    /// clamped; a price of exactly 0 or 1 falls back to whole-cent price (no real odds to
    /// quote at the extremes).
    public func format(_ price: Decimal) -> String {
        let p = NSDecimalNumber(decimal: min(max(price, 0), 1)).doubleValue
        guard p > 0, p < 1 else { return MarketFormatting.centsWhole(price) }

        switch self {
        case .price:      return MarketFormatting.centsWhole(price)
        case .percentage: return MarketFormatting.percent(price)
        case .american:   return Self.americanString(p)
        case .decimal:    return Self.twoDecimals(1 / p)
        case .fractional: return Self.fractionalString(p)
        case .hongKong:   return Self.twoDecimals((1 - p) / p)
        case .indonesian:
            return p > 0.5 ? Self.signed(-p / (1 - p)) : Self.signed((1 - p) / p)
        case .malaysian:
            return p > 0.5 ? Self.signed(-(1 - p) / p) : Self.signed(p / (1 - p))
        }
    }

    /// American odds: negative for favorites (p > 50%), positive for underdogs/even money.
    private static func americanString(_ p: Double) -> String {
        let value = p > 0.5 ? -100 * p / (1 - p) : 100 * (1 - p) / p
        return signed(value, decimals: 0)
    }

    /// "3/2"-style odds: the simplest fraction (denominator ≤ 100) approximating `(1-p)/p`,
    /// found via continued-fraction convergents.
    private static func fractionalString(_ p: Double) -> String {
        let (numerator, denominator) = bestRational((1 - p) / p, maxDenominator: 100)
        return "\(numerator)/\(denominator)"
    }

    /// The convergent of `value`'s continued-fraction expansion with the largest denominator
    /// that still fits within `maxDenominator` — the standard way to find the simplest
    /// fraction approximating a real number.
    private static func bestRational(_ value: Double, maxDenominator: Int) -> (Int, Int) {
        guard value.isFinite, value > 0 else { return (0, 1) }
        var (h0, h1) = (0.0, 1.0)
        var (k0, k1) = (1.0, 0.0)
        var remainder = value
        var (bestH, bestK) = (1.0, 1.0)
        for _ in 0..<32 {
            let wholePart = remainder.rounded(.down)
            let h2 = wholePart * h1 + h0
            let k2 = wholePart * k1 + k0
            guard k2 <= Double(maxDenominator) else { break }
            (bestH, bestK) = (h2, k2)
            if abs(value - h2 / k2) < 1e-9 { break }
            let fraction = remainder - wholePart
            guard fraction > 1e-9 else { break }
            remainder = 1 / fraction
            (h0, h1) = (h1, h2)
            (k0, k1) = (k1, k2)
        }
        return (Int(bestH), Int(bestK))
    }

    /// Two-decimal string with no sign, e.g. "1.50".
    private static func twoDecimals(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    /// Signed string (explicit "+"/"-") with the given decimal places (default 2).
    private static func signed(_ value: Double, decimals: Int = 2) -> String {
        let sign = value >= 0 ? "+" : "-"
        return "\(sign)\(String(format: "%.\(decimals)f", abs(value)))"
    }
}
