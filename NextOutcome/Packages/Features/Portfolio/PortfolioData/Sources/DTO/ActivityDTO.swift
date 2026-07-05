//
//  ActivityDTO.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import Foundation

/// Data API `/activity` row. `type` is TRADE/SPLIT/MERGE/REDEEM/REWARD/CONVERSION;
/// TRADE rows carry a `side` (BUY/SELL). Numeric fields tolerated as number-or-string.
struct ActivityDTO: Decodable {
    /// The activity type (TRADE/SPLIT/MERGE/…).
    let type: String?
    /// For TRADE rows, BUY or SELL.
    let side: String?
    /// The market title.
    let title: String?
    /// The market's URL slug.
    let slug: String?
    /// The outcome involved.
    let outcome: String?
    /// The market icon URL string.
    let icon: String?
    /// Shares involved.
    let size: Decimal
    /// USD notional.
    let usdcSize: Decimal
    /// Price per share (0…1).
    let price: Decimal
    /// Unix timestamp in seconds.
    let timestamp: Double
    /// The on-chain transaction hash, used as a stable id.
    let transactionHash: String?
    /// The market's condition id.
    let conditionId: String?

    /// JSON keys for `ActivityDTO`.
    enum CodingKeys: String, CodingKey {
        case type, side, title, slug, outcome, icon
        case size, usdcSize, price, timestamp, transactionHash, conditionId
    }

    /// Custom decoder tolerating missing strings and number-or-string numeric fields.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        type = try? c.decode(String.self, forKey: .type)
        side = try? c.decode(String.self, forKey: .side)
        title = try? c.decode(String.self, forKey: .title)
        slug = try? c.decode(String.self, forKey: .slug)
        outcome = try? c.decode(String.self, forKey: .outcome)
        icon = try? c.decode(String.self, forKey: .icon)
        size = PortfolioDecoding.decimal(c, .size)
        usdcSize = PortfolioDecoding.decimal(c, .usdcSize)
        price = PortfolioDecoding.decimal(c, .price)
        timestamp = (try? c.decode(Double.self, forKey: .timestamp)) ?? 0
        transactionHash = try? c.decode(String.self, forKey: .transactionHash)
        conditionId = try? c.decode(String.self, forKey: .conditionId)
    }
}
