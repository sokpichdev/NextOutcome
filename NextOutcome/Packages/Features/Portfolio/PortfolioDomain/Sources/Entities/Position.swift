//
//  Position.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import Foundation

/// A single open position for a watched wallet. PnL fields are pre-computed by the Data API.
public struct Position: Identifiable, Hashable, Sendable {
    public let id: String            // token id (asset)
    public let conditionId: String
    public let title: String
    public let slug: String
    public let outcome: String       // "Yes" / "No" / outcome label
    public let iconURL: URL?
    public let size: Decimal
    public let avgPrice: Decimal
    public let curPrice: Decimal
    public let currentValue: Decimal
    public let cashPnl: Decimal
    public let percentPnl: Decimal
    public let redeemable: Bool

    public init(
        id: String,
        conditionId: String,
        title: String,
        slug: String,
        outcome: String,
        iconURL: URL?,
        size: Decimal,
        avgPrice: Decimal,
        curPrice: Decimal,
        currentValue: Decimal,
        cashPnl: Decimal,
        percentPnl: Decimal,
        redeemable: Bool
    ) {
        self.id = id
        self.conditionId = conditionId
        self.title = title
        self.slug = slug
        self.outcome = outcome
        self.iconURL = iconURL
        self.size = size
        self.avgPrice = avgPrice
        self.curPrice = curPrice
        self.currentValue = currentValue
        self.cashPnl = cashPnl
        self.percentPnl = percentPnl
        self.redeemable = redeemable
    }

    public var isProfitable: Bool { cashPnl >= 0 }
}
