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
    let type: String?
    let side: String?
    let title: String?
    let slug: String?
    let outcome: String?
    let icon: String?
    let size: Decimal
    let usdcSize: Decimal
    let price: Decimal
    let timestamp: Double
    let transactionHash: String?
    let conditionId: String?

    enum CodingKeys: String, CodingKey {
        case type, side, title, slug, outcome, icon
        case size, usdcSize, price, timestamp, transactionHash, conditionId
    }

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
