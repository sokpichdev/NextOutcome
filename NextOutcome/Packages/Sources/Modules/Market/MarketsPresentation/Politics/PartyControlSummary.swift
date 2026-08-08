//
//  PartyControlSummary.swift
//  NextOutcome
//
//  Created by Sok Pich on 05/07/2026.
//

import Foundation
import MarketsDomain

/// The headline "{X}% chance {Party} win the {Chamber}" summary for a party-control market
/// (e.g. "Which party will win the Senate in 2026?"), naming whichever side is ahead.
public struct PartyControlSummary: Equatable {
    /// The leading party's display name, e.g. "Democrats" or "Republicans".
    public let leadingParty: String
    /// The leading party's win chance (0…1).
    public let percent: Decimal
    /// The leading party's own market — trading its Yes side backs that outcome.
    public let market: Market

    /// Builds a summary from a control event's two party markets, naming whichever is ahead.
    /// - Parameter event: The control event (e.g. "Which party will win the Senate in 2026?").
    /// - Returns: The summary, or `nil` if the event has no recognizable party markets.
    public static func summary(for event: Event?) -> PartyControlSummary? {
        guard let event else { return nil }
        let democrat = event.markets.first { ($0.groupItemTitle ?? $0.question).lowercased().contains("democrat") }
        let republican = event.markets.first { ($0.groupItemTitle ?? $0.question).lowercased().contains("republican") }
        guard let dMarket = democrat, let dPrice = dMarket.yesOutcome?.price,
              let rMarket = republican, let rPrice = rMarket.yesOutcome?.price else { return nil }
        return dPrice >= rPrice
            ? PartyControlSummary(leadingParty: "Democrats", percent: dPrice, market: dMarket)
            : PartyControlSummary(leadingParty: "Republicans", percent: rPrice, market: rMarket)
    }
}
