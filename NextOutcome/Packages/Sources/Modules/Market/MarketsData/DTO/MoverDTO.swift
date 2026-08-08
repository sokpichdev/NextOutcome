//
//  MoverDTO.swift
//  NextOutcome
//
//  Created by Sok Pich on 05/07/2026.
//

import Foundation

/// A row from Gamma `/markets` used to build a Breaking-feed `Mover`. Unlike the embedded
/// `MarketDTO` (which comes nested inside an event), a top-level `/markets` row carries the
/// 24h price-change and volume fields plus an `events` array pointing back at its parent
/// event (needed to open the grouped movers chart). Decoding is tolerant: a missing/odd
/// field degrades a single mover rather than failing the whole page.
struct MoverDTO: Decodable {
    /// The market id.
    let id: String
    /// The market question.
    let question: String
    /// The market image URL string, if any.
    let image: String?
    /// The market icon URL string, if any (fallback when `image` is absent).
    let icon: String?
    /// The last traded price (0…1), used as a probability fallback when `outcomePrices` is empty.
    let lastTradePrice: Decimal?
    /// Outcome prices (0…1), parsed from a stringified array. `first` is the "Yes"/current chance.
    let outcomePrices: [Decimal]
    /// The 24h change in implied probability, in points (roughly -1…1).
    let oneDayPriceChange: Decimal
    /// 24h traded volume.
    let volume24hr: Decimal
    /// The parent event(s) this market belongs to; `first` supplies the slug/title/icon.
    let events: [ParentEventDTO]

    /// The slice of a parent event that a mover needs: enough to open the grouped chart.
    struct ParentEventDTO: Decodable {
        /// The parent event's URL slug (used to fetch the full event for the chart).
        let slug: String?
        /// The parent event's title (shown in the detail header).
        let title: String?
        /// The parent event's image URL string.
        let image: String?
        /// The parent event's icon URL string.
        let icon: String?
    }

    /// JSON keys for `MoverDTO`.
    enum CodingKeys: String, CodingKey {
        case id, question, image, icon, lastTradePrice, outcomePrices
        case oneDayPriceChange, volume24hr, events
    }

    /// Tolerant decoder: missing/odd fields degrade a single mover rather than failing the page.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        question = (try? c.decode(String.self, forKey: .question)) ?? ""
        image = try? c.decode(String.self, forKey: .image)
        icon = try? c.decode(String.self, forKey: .icon)
        if let last = try? c.decode(Double.self, forKey: .lastTradePrice) {
            lastTradePrice = Decimal(last)
        } else {
            lastTradePrice = nil
        }
        outcomePrices = DTODecoding.stringArray(c, .outcomePrices).compactMap { Decimal(string: $0) }
        oneDayPriceChange = DTODecoding.decimal(c, .oneDayPriceChange)
        volume24hr = DTODecoding.decimal(c, .volume24hr)
        events = (try? c.decode([ParentEventDTO].self, forKey: .events)) ?? []
    }
}
