//
//  MarketGroupClassifier.swift
//  NextOutcome
//
//  Created by Sok Pich on 03/07/2026.
//

import Foundation

/// Live-site section a sports market belongs to on an event-detail page.
public enum MarketGroup: String, CaseIterable, Sendable {
    case moneyline, spreads, totals, bothTeamsToScore, firstToScore
    case teamTotals, extraTime, penaltyShootout, other

    /// The section header text shown on the event-detail page.
    public var title: String {
        switch self {
        case .moneyline: return "Moneyline"
        case .spreads: return "Spreads"
        case .totals: return "Totals"
        case .bothTeamsToScore: return "Both Teams to Score"
        case .firstToScore: return "First Team to Score"
        case .teamTotals: return "Team Totals"
        case .extraTime: return "Extra Time"
        case .penaltyShootout: return "Penalty Shootout"
        case .other: return "Other"
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
            let sorted = bucket.sorted { ($0.yesOutcome?.price ?? 0) > ($1.yesOutcome?.price ?? 0) }
            return (group: group, markets: sorted)
        }
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
