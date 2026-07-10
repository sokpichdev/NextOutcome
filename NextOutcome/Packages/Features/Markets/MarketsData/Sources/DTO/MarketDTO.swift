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
    /// The market id.
    let id: String
    /// The condition id (for holders/CLOB lookups).
    let conditionId: String
    /// The market question.
    let question: String
    /// The market's URL slug.
    let slug: String
    /// Outcome labels, parsed from a stringified array.
    let outcomes: [String]
    /// Outcome prices (0…1), parallel to `outcomes`.
    let outcomePrices: [Decimal]
    /// CLOB token ids, parallel to `outcomes`.
    let clobTokenIds: [String]
    /// Total traded volume.
    let volume: Decimal
    /// Available liquidity.
    let liquidity: Decimal
    /// The close date as a full ISO8601 timestamp, if present. Decoded from the wire's
    /// `endDate` key — Gamma's `endDateIso` key is a bare `"yyyy-MM-dd"` date with no time
    /// component, which `DateParsing` can't parse (it only accepts full timestamps).
    let endDate: String?
    /// Whether the market is closed/resolved.
    let closed: Bool
    /// Gamma's tradeable flag. `false` for undetermined placeholder slots
    /// (e.g. "Team AG" World Cup qualifiers) that have no prices/liquidity yet.
    let active: Bool
    let image: String?
    /// Sports section hint, e.g. "moneyline" / "spreads" / "totals". Absent for non-sports markets.
    let sportsMarketType: String?
    /// Sports sub-label, e.g. a team name or "Both Teams to Score". Absent for non-sports markets.
    let groupItemTitle: String?
    /// Resolution-criteria text. Absent for many markets.
    let description: String?
    /// A sports market's kickoff time, in Gamma's space-separated form
    /// (`"2026-06-11 19:00:00+00"`). Absent for non-sports markets. Gamma only carries this
    /// per-market, never on the parent event — `MarketMapper.event(from:)` promotes the
    /// earliest one up to the event level.
    let gameStartTime: String?

    /// JSON keys for `MarketDTO`.
    enum CodingKeys: String, CodingKey {
        case id, conditionId, question, slug, outcomes, outcomePrices, clobTokenIds
        case volume, liquidity, endDate, closed, active, image
        case sportsMarketType, groupItemTitle, description, gameStartTime
    }

    /// Tolerant decoder: missing/odd fields degrade a single market rather than failing the
    /// whole page, and the parallel stringified arrays are parsed via `DTODecoding`.
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
        endDate = try? c.decode(String.self, forKey: .endDate)
        closed = (try? c.decode(Bool.self, forKey: .closed)) ?? false
        // Default to tradeable when absent so we never hide a real market on a missing
        // field; placeholders explicitly send `active: false`.
        active = (try? c.decode(Bool.self, forKey: .active)) ?? true
        image = try? c.decode(String.self, forKey: .image)
        sportsMarketType = try? c.decode(String.self, forKey: .sportsMarketType)
        groupItemTitle = try? c.decode(String.self, forKey: .groupItemTitle)
        description = try? c.decode(String.self, forKey: .description)
        gameStartTime = try? c.decode(String.self, forKey: .gameStartTime)
    }
}

/// Gamma `/events` row wrapping several `MarketDTO`s. Tolerant decoding: a missing `title`
/// falls back to the slug, missing arrays default to empty.
struct EventDTO: Decodable {
    /// The event id.
    let id: String
    /// The event title (falls back to the slug when absent).
    let title: String
    /// The event's URL slug.
    let slug: String
    /// The markets embedded in this event.
    let markets: [MarketDTO]
    /// Total event volume.
    let volume: Decimal
    /// The event image URL string, if any.
    let image: String?
    /// The event's category tags.
    let tags: [TagDTO]
    /// Kickoff time for sports events. Absent for non-sports events.
    let gameStartTime: String?
    /// Event-level context/description. Absent for many events.
    let description: String?
    /// The recurring-market series this event belongs to, if any. Real payloads carry at
    /// most one entry; absent for non-recurring events.
    let series: [SeriesDTO]
    /// Trailing-24-hour trading volume.
    let volume24hr: Decimal
    /// Available liquidity in dollars.
    let liquidity: Decimal
    /// A 0-1 "competitiveness" score Gamma computes (how close to 50/50 the market is).
    let competitive: Double?
    /// When the event was created, ISO8601 with fractional seconds.
    let creationDate: String?

    /// JSON keys for `EventDTO`.
    enum CodingKeys: String, CodingKey {
        case id, title, slug, markets, volume, image, tags, gameStartTime, description, series,
             volume24hr, liquidity, competitive, creationDate
    }

    /// Tolerant decoder falling back to the slug for a missing title and to empty
    /// collections for missing arrays.
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
        gameStartTime = try? c.decode(String.self, forKey: .gameStartTime)
        description = try? c.decode(String.self, forKey: .description)
        series = (try? c.decode([SeriesDTO].self, forKey: .series)) ?? []
        volume24hr = DTODecoding.decimal(c, .volume24hr)
        liquidity = DTODecoding.decimal(c, .liquidity)
        competitive = try? c.decode(Double.self, forKey: .competitive)
        creationDate = try? c.decode(String.self, forKey: .creationDate)
    }
}

/// Gamma tag row (category).
struct TagDTO: Decodable {
    /// The tag id.
    let id: String
    /// The display label.
    let label: String
    /// The tag's URL slug.
    let slug: String
}

/// Gamma series row — identifies a recurring market family (e.g. "BTC Up or Down 5m").
/// Only `slug` is needed: it encodes the recurrence cadence as a suffix (`-5m`, `-15m`,
/// `-hourly`, `-4h`, `-daily`), which is more reliable than the JSON `recurrence` field
/// (verified against live data: a "4h"-cadence series reports `"daily"` there).
struct SeriesDTO: Decodable {
    /// The series slug, e.g. `"btc-up-or-down-5m"`.
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
