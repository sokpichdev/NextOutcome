//
//  PropsFilter.swift
//  NextOutcome
//
//  Created by Sok Pich on 04/07/2026.
//

import MarketsDomain

/// Sub-filters of the hub's Props tab. Pure keyword/market-type heuristics over live Gamma
/// data — the API exposes no prop taxonomy, so the constants below pin today's patterns.
public enum PropsFilter: String, CaseIterable, Sendable {
    case all, awards, playerH2H, groupFutures

    /// The chip label for this filter.
    public var title: String {
        switch self {
        case .all:          return "All"
        case .awards:       return "Awards"
        case .playerH2H:    return "Player H2H"
        case .groupFutures: return "Group Futures"
        }
    }

    /// Title keywords that identify award markets (Golden Boot, etc.).
    static let awardKeywords = ["golden boot", "golden ball", "golden glove", "best young", "award"]
    /// The sports-market-type prefix that identifies player-vs-player markets.
    static let playerMarketTypePrefix = "soccer_player"

    /// Whether an event belongs to this filter, using keyword/market-type heuristics.
    /// - Parameter event: The event to test.
    /// - Returns: `true` if the event matches this filter (`.all` always matches).
    public func matches(_ event: Event) -> Bool {
        let title = event.title.lowercased()
        switch self {
        case .all:
            return true
        case .awards:
            return Self.awardKeywords.contains { title.contains($0) }
        case .playerH2H:
            return title.contains("h2h")
                || event.markets.contains { $0.sportsMarketType?.hasPrefix(Self.playerMarketTypePrefix) == true }
        case .groupFutures:
            return title.contains("group ")
        }
    }
}
