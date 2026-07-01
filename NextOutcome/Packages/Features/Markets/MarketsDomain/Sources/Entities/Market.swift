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
        imageURL: URL?
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
    }
    public var yesOutcome: Outcome? { outcomes.first { $0.title == "Yes" } }
    public var noOutcome: Outcome? { outcomes.first { $0.title == "No" } }
}
