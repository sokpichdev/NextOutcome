//
//  MarketGroupClassifier.swift
//  NextOutcome
//
//  Created by Sok Pich on 03/07/2026.
//

import Foundation

/// Live-site section a sports market belongs to on an event-detail page.
///
/// Declaration order **is** section order — `allCases` drives `MarketGroupClassifier.groups`.
/// The esports sections sit next to their sports analogue so a mixed event still reads in a
/// sensible order, and the existing relative order of the sports cases is untouched.
public enum MarketGroup: String, CaseIterable, Sendable {
    case moneyline, mapWinner, spreads, mapHandicap, totals, mapTotals, mapRoundHandicap
    case bothTeamsToScore, firstToScore
    case teamTotals, extraTime, penaltyShootout, other

    /// The section header text shown on the event-detail page.
    public var title: String {
        switch self {
        case .moneyline: return "Moneyline"
        case .mapWinner: return "Map Winners"
        case .spreads: return "Spreads"
        case .mapHandicap: return "Map Handicap"
        case .totals: return "Totals"
        case .mapTotals: return "Map Rounds"
        case .mapRoundHandicap: return "Map Round Handicap"
        case .bothTeamsToScore: return "Both Teams to Score"
        case .firstToScore: return "First Team to Score"
        case .teamTotals: return "Team Totals"
        case .extraTime: return "Extra Time"
        case .penaltyShootout: return "Penalty Shootout"
        case .other: return "Other"
        }
    }

    /// Whether this section lists one market per map, so it should be ordered by map number
    /// rather than by price.
    var isPerMap: Bool {
        switch self {
        case .mapWinner, .mapTotals, .mapRoundHandicap: return true
        default: return false
        }
    }
}

/// Pure classifier that groups an event's markets into live-site sections
/// (Moneyline, Spreads, Totals, …), mirroring the ordering shown on the live site.
public enum MarketGroupClassifier {
    /// Pure. Groups an event's markets in live-site section order.
    /// Empty groups are omitted; within a group markets are sorted by Yes-probability
    /// descending (matching the live site), so real contenders lead and unpriced
    /// placeholder markets — e.g. not-yet-qualified "Team A" slots priced at 0 — sink to
    /// the bottom instead of cluttering the top.
    public static func groups(for markets: [Market]) -> [(group: MarketGroup, markets: [Market])] {
        var buckets: [MarketGroup: [Market]] = [:]
        for market in markets {
            buckets[classify(market), default: []].append(market)
        }
        return MarketGroup.allCases.compactMap { group in
            guard let bucket = buckets[group], !bucket.isEmpty else { return nil }
            return (group: group, markets: bucket.sorted { isOrderedBefore($0, $1, in: group) })
        }
    }

    /// The in-section ordering.
    ///
    /// Per-map sections read in map order — "Map 1 Winner" above "Map 2 Winner" — because
    /// that's the sequence they're played in; price ordering would shuffle them as the
    /// series progresses. Everywhere else the highest chance leads, matching the live site,
    /// so real contenders sit above unpriced placeholder slots.
    ///
    /// `primaryOutcome`, not `yesOutcome`: team-named markets have no Yes side, so every key
    /// would be 0 — and `sorted` is not stable, so equal keys let rows shuffle between
    /// redraws. The `id` tiebreak is what pins the order.
    private static func isOrderedBefore(_ a: Market, _ b: Market, in group: MarketGroup) -> Bool {
        if group.isPerMap {
            // Markets whose map is unknown sink below the numbered ones rather than leading.
            let mapA = mapNumber(for: a) ?? .max
            let mapB = mapNumber(for: b) ?? .max
            if mapA != mapB { return mapA < mapB }
        }
        let priceA = a.primaryOutcome?.price ?? 0
        let priceB = b.primaryOutcome?.price ?? 0
        if priceA != priceB { return priceA > priceB }
        return a.id < b.id
    }

    /// Which map of a series a market covers (`"round_over_under_game_2"` → 2), or `nil` when
    /// it isn't map-specific.
    ///
    /// Prefers the trailing number on Gamma's `sportsMarketType`, falling back to the "Map N"
    /// in the market's own label — `child_moneyline` carries no number, so "Map 1 Winner" is
    /// the only place its map is named.
    /// - Parameter market: The market to place.
    public static func mapNumber(for market: Market) -> Int? {
        if let type = market.sportsMarketType?.lowercased(),
           let trailing = type.split(separator: "_").last,
           let number = Int(trailing) {
            return number
        }
        let label = (market.groupItemTitle ?? market.question).lowercased()
        guard let range = label.range(of: #"map\s+(\d+)"#, options: .regularExpression) else { return nil }
        return Int(label[range].filter(\.isNumber))
    }

    /// Classifies a single market into a `MarketGroup`, preferring Gamma's
    /// `sportsMarketType` and falling back to keyword-matching the title/subtitle.
    /// - Parameter market: The market to classify.
    /// - Returns: The section it belongs to (`.other` if nothing matches).
    private static func classify(_ market: Market) -> MarketGroup {
        switch market.sportsMarketType?.lowercased() {
        case "moneyline": return .moneyline
        case "spreads": return .spreads
        case "totals": return .totals
        case "child_moneyline": return .mapWinner
        case "map_handicap": return .mapHandicap
        case let type?:
            // Matched by prefix, not equality: the live keys are `round_over_under_game_1|2|3`
            // and `round_handicap_game_1|2`, and the suffix grows with the series length —
            // an exhaustive list would silently drop a Bo5's map 4 and 5 markets into "Other".
            if type.hasPrefix("round_over_under") { return .mapTotals }
            if type.hasPrefix("round_handicap") { return .mapRoundHandicap }
        default: break
        }

        let haystack = [market.groupItemTitle, market.question]
            .compactMap { $0?.lowercased() }
            .joined(separator: " ")

        if haystack.contains("both teams to score") { return .bothTeamsToScore }
        if haystack.contains("first team to score") { return .firstToScore }
        if haystack.contains("extra time") { return .extraTime }
        if haystack.contains("penalty shootout") { return .penaltyShootout }
        if haystack.contains("totals") { return .teamTotals }
        return .other
    }
}
