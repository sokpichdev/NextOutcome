//
//  PositionDTO.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import Foundation

/// Data API `/positions` row. Numeric fields arrive as JSON numbers (or occasionally
/// strings); `Decimal` decoding is tolerant via the custom initializer.
struct PositionDTO: Decodable {
    /// The outcome token id.
    let asset: String
    /// The market's condition id.
    let conditionId: String
    /// The market title.
    let title: String?
    /// The market's URL slug.
    let slug: String?
    /// The outcome held.
    let outcome: String?
    /// The market icon URL string.
    let icon: String?
    /// Shares held.
    let size: Decimal
    /// Average price paid (0…1).
    let avgPrice: Decimal
    /// Current market price (0…1).
    let curPrice: Decimal
    /// Current dollar value.
    let currentValue: Decimal
    /// Unrealized dollar PnL.
    let cashPnl: Decimal
    /// Unrealized percent PnL.
    let percentPnl: Decimal
    /// Whether the position is redeemable.
    let redeemable: Bool

    /// JSON keys for `PositionDTO`.
    enum CodingKeys: String, CodingKey {
        case asset, conditionId, title, slug, outcome, icon
        case size, avgPrice, curPrice, currentValue, cashPnl, percentPnl, redeemable
    }

    /// Custom decoder that tolerates missing strings and number-or-string numeric fields,
    /// falling back to sensible defaults rather than throwing on partial data.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        asset = try c.decode(String.self, forKey: .asset)
        conditionId = (try? c.decode(String.self, forKey: .conditionId)) ?? ""
        title = try? c.decode(String.self, forKey: .title)
        slug = try? c.decode(String.self, forKey: .slug)
        outcome = try? c.decode(String.self, forKey: .outcome)
        icon = try? c.decode(String.self, forKey: .icon)
        size = PortfolioDecoding.decimal(c, .size)
        avgPrice = PortfolioDecoding.decimal(c, .avgPrice)
        curPrice = PortfolioDecoding.decimal(c, .curPrice)
        currentValue = PortfolioDecoding.decimal(c, .currentValue)
        cashPnl = PortfolioDecoding.decimal(c, .cashPnl)
        percentPnl = PortfolioDecoding.decimal(c, .percentPnl)
        redeemable = (try? c.decode(Bool.self, forKey: .redeemable)) ?? false
    }
}

/// Data API `/value` — either `[{ "user": ..., "value": 1.23 }]` or `{ "value": 1.23 }`.
struct PortfolioValueDTO: Decodable {
    /// The total portfolio value.
    let value: Decimal

    /// JSON keys for `PortfolioValueDTO`.
    enum CodingKeys: String, CodingKey { case value }

    /// Custom decoder tolerating number-or-string values.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        value = PortfolioDecoding.decimal(c, .value)
    }
}

/// Shared decoding helpers for the portfolio DTOs, which frequently receive numbers encoded
/// as either JSON numbers or strings.
enum PortfolioDecoding {
    /// Decodes a `Decimal` for a key, accepting either a JSON number or a numeric string,
    /// and defaulting to `0` when the value is missing or unparseable.
    /// - Parameters:
    ///   - c: The keyed decoding container.
    ///   - key: The key to read.
    /// - Returns: The parsed decimal, or `0`.
    static func decimal<K: CodingKey>(_ c: KeyedDecodingContainer<K>, _ key: K) -> Decimal {
        if let d = try? c.decode(Decimal.self, forKey: key) { return d }
        if let s = try? c.decode(String.self, forKey: key), let d = Decimal(string: s) { return d }
        return 0
    }
}
