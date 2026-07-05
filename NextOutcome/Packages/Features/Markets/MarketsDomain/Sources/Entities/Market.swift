//
//  Market.swift
//  NextOutcome
//
//  Created by Sok Pich on 30/06/2026.
//

import Foundation
import SharedDomain

/// A single prediction market — one question with a set of tradeable outcomes. Several
/// markets can belong to one `Event` (e.g. a sports game's moneyline, spread, and totals).
public struct Market: Identifiable, Hashable {
    /// The market's unique id.
    public let id: String
    /// The condition id used for holders / CLOB lookups.
    public let conditionId: String   // for holders / CLOB lookups
    /// The market question (e.g. "Will X win?").
    public let question: String
    /// The market's URL slug.
    public let slug: String
    /// The tradeable outcomes (e.g. Yes/No, or team choices).
    public let outcomes: [Outcome]
    /// Total traded volume in dollars.
    public let volume: Decimal
    /// Available liquidity in dollars.
    public let liquidity: Decimal
    /// When the market closes, if known.
    public let endDate: Date?
    /// Whether the market has resolved.
    public let isResolved: Bool
    /// Tradeable per Gamma's `active` flag. `false` for undetermined placeholder outcomes
    /// (e.g. not-yet-qualified "Team AG" slots) that carry no prices and shouldn't be listed.
    public let isActive: Bool
    public let imageURL: URL?
    /// Sports section hint from Gamma, e.g. "moneyline" / "spreads" / "totals". Absent for non-sports markets.
    public let sportsMarketType: String?
    /// Sports sub-label from Gamma, e.g. a team name or "Both Teams to Score". Absent for non-sports markets.
    public let groupItemTitle: String?
    /// Full resolution-criteria text from Gamma's per-market `description`, shown in the Rules expander.
    public let rules: String?

    /// Creates a market. Most callers are the mapping layer turning a DTO into this type.
    public init(
        id: String,
        conditionId: String = "",
        question: String,
        slug: String,
        outcomes: [Outcome],
        volume: Decimal,
        liquidity: Decimal,
        endDate: Date?,
        isResolved: Bool,
        isActive: Bool = true,
        imageURL: URL?,
        sportsMarketType: String? = nil,
        groupItemTitle: String? = nil,
        rules: String? = nil
    ) {
        self.id = id
        self.conditionId = conditionId
        self.question = question
        self.slug = slug
        self.outcomes = outcomes
        self.volume = volume
        self.liquidity = liquidity
        self.endDate = endDate
        self.isResolved = isResolved
        self.isActive = isActive
        self.imageURL = imageURL
        self.sportsMarketType = sportsMarketType
        self.groupItemTitle = groupItemTitle
        self.rules = rules
    }
    /// The "Yes" outcome for a binary market, if present.
    public var yesOutcome: Outcome? { outcomes.first { $0.title == "Yes" } }
    /// The "No" outcome for a binary market, if present.
    public var noOutcome: Outcome? { outcomes.first { $0.title == "No" } }
}
