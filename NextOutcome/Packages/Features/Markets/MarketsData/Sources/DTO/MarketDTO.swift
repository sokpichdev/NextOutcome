//
//  MarketDTO.swift
//  NextOutcome
//
//  Created by Sok Pich on 30/06/2026.
//

import Foundation
import Networking

/// Gamma `/events` embeds markets with parallel *stringified* arrays
/// (`outcomes`, `outcomePrices`, `clobTokenIds`) rather than a `tokens` array,
/// and several fields are frequently absent. Decoding is deliberately tolerant:
/// a missing/odd field degrades that market, it never fails the whole page.
struct MarketDTO: Decodable {
    let id: String
    let conditionId: String
    let question: String
    let slug: String
    let outcomes: [String]
    let outcomePrices: [Decimal]
    let clobTokenIds: [String]
    let volume: Decimal
    let liquidity: Decimal
    let endDateIso: String?
    let closed: Bool
    let image: String?
    /// Sports section hint, e.g. "moneyline" / "spreads" / "totals". Absent for non-sports markets.
    let sportsMarketType: String?
    /// Sports sub-label, e.g. a team name or "Both Teams to Score". Absent for non-sports markets.
    let groupItemTitle: String?

    enum CodingKeys: String, CodingKey {
        case id, conditionId, question, slug, outcomes, outcomePrices, clobTokenIds
        case volume, liquidity, endDateIso, closed, image
        case sportsMarketType, groupItemTitle
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        conditionId = (try? c.decode(String.self, forKey: .conditionId)) ?? ""
        question = (try? c.decode(String.self, forKey: .question)) ?? ""
        slug = (try? c.decode(String.self, forKey: .slug)) ?? ""
        outcomes = DTODecoding.stringArray(c, .outcomes)
        outcomePrices = DTODecoding.stringArray(c, .outcomePrices).compactMap { Decimal(string: $0) }
        clobTokenIds = DTODecoding.stringArray(c, .clobTokenIds)
        volume = DTODecoding.decimal(c, .volume)
        liquidity = DTODecoding.decimal(c, .liquidity)
        endDateIso = try? c.decode(String.self, forKey: .endDateIso)
        closed = (try? c.decode(Bool.self, forKey: .closed)) ?? false
        image = try? c.decode(String.self, forKey: .image)
        sportsMarketType = try? c.decode(String.self, forKey: .sportsMarketType)
        groupItemTitle = try? c.decode(String.self, forKey: .groupItemTitle)
    }
}

struct EventDTO: Decodable {
    let id: String
    let title: String
    let slug: String
    let markets: [MarketDTO]
    let volume: Decimal
    let image: String?
    let tags: [TagDTO]

    enum CodingKeys: String, CodingKey {
        case id, title, slug, markets, volume, image, tags
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        slug = (try? c.decode(String.self, forKey: .slug)) ?? ""
        // Some events (older sports markets) omit `title` — fall back to the slug.
        title = (try? c.decode(String.self, forKey: .title)) ?? slug
        markets = (try? c.decode([MarketDTO].self, forKey: .markets)) ?? []
        volume = DTODecoding.decimal(c, .volume)
        image = try? c.decode(String.self, forKey: .image)
        tags = (try? c.decode([TagDTO].self, forKey: .tags)) ?? []
    }
}

struct TagDTO: Decodable {
    let id: String
    let label: String
    let slug: String
}

/// Shared tolerant field helpers for the Gamma wire shape.
enum DTODecoding {
    /// Decodes a value that may be a real JSON array or a stringified one
    /// (`"[\"Yes\",\"No\"]"`). Missing/garbage → `[]`.
    static func stringArray<K: CodingKey>(_ c: KeyedDecodingContainer<K>, _ key: K) -> [String] {
        if let raw = try? c.decode(String.self, forKey: key),
           let data = raw.data(using: .utf8),
           let arr = try? JSONDecoder().decode([String].self, from: data) {
            return arr
        }
        return (try? c.decode([String].self, forKey: key)) ?? []
    }

    /// Decodes a `Decimal` from either a numeric-string (`"60576.5"`) or a JSON number. Missing → 0.
    static func decimal<K: CodingKey>(_ c: KeyedDecodingContainer<K>, _ key: K) -> Decimal {
        if let s = try? c.decode(String.self, forKey: key), let d = Decimal(string: s) { return d }
        if let dbl = try? c.decode(Double.self, forKey: key) { return Decimal(dbl) }
        return 0
    }
}
