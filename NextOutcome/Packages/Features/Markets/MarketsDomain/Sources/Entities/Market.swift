//
//  Market.swift
//  NextOutcome
//
//  Created by Sok Pich on 30/06/2026.
//

import Foundation
import SharedDomain

public struct Market: Identifiable, Hashable {
    public let id: String
    public let conditionId: String   // for holders / CLOB lookups
    public let question: String
    public let slug: String
    public let outcomes: [Outcome]
    public let volume: Decimal
    public let liquidity: Decimal
    public let endDate: Date?
    public let isResolved: Bool
    public let imageURL: URL?
    /// Sports section hint from Gamma, e.g. "moneyline" / "spreads" / "totals". Absent for non-sports markets.
    public let sportsMarketType: String?
    /// Sports sub-label from Gamma, e.g. a team name or "Both Teams to Score". Absent for non-sports markets.
    public let groupItemTitle: String?
    /// Full resolution-criteria text from Gamma's per-market `description`, shown in the Rules expander.
    public let rules: String?

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
        self.imageURL = imageURL
        self.sportsMarketType = sportsMarketType
        self.groupItemTitle = groupItemTitle
        self.rules = rules
    }
    public var yesOutcome: Outcome? { outcomes.first { $0.title == "Yes" } }
    public var noOutcome: Outcome? { outcomes.first { $0.title == "No" } }
}
