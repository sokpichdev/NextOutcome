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
    let asset: String
    let conditionId: String
    let title: String?
    let slug: String?
    let outcome: String?
    let icon: String?
    let size: Decimal
    let avgPrice: Decimal
    let curPrice: Decimal
    let currentValue: Decimal
    let cashPnl: Decimal
    let percentPnl: Decimal
    let redeemable: Bool

    enum CodingKeys: String, CodingKey {
        case asset, conditionId, title, slug, outcome, icon
        case size, avgPrice, curPrice, currentValue, cashPnl, percentPnl, redeemable
    }

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
    let value: Decimal

    enum CodingKeys: String, CodingKey { case value }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        value = PortfolioDecoding.decimal(c, .value)
    }
}

enum PortfolioDecoding {
    static func decimal<K: CodingKey>(_ c: KeyedDecodingContainer<K>, _ key: K) -> Decimal {
        if let d = try? c.decode(Decimal.self, forKey: key) { return d }
        if let s = try? c.decode(String.self, forKey: key), let d = Decimal(string: s) { return d }
        return 0
    }
}
