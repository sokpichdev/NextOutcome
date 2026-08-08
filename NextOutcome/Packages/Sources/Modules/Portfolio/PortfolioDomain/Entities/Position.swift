//
//  Position.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import Foundation

/// A single open position for a watched wallet. PnL fields are pre-computed by the Data API.
public struct Position: Identifiable, Hashable, Sendable {
    /// The outcome token id (also this position's stable identity).
    public let id: String            // token id (asset)
    /// The market's condition id (groups all outcomes of one market).
    public let conditionId: String
    /// The market title.
    public let title: String
    /// The market's URL slug.
    public let slug: String
    /// The outcome held, e.g. "Yes"/"No" or an outcome label.
    public let outcome: String       // "Yes" / "No" / outcome label
    /// The market's icon image, if any.
    public let iconURL: URL?
    /// Number of shares held.
    public let size: Decimal
    /// The average price paid per share (0…1).
    public let avgPrice: Decimal
    /// The current market price per share (0…1).
    public let curPrice: Decimal
    /// The position's current dollar value.
    public let currentValue: Decimal
    /// Unrealized profit/loss in dollars (pre-computed by the API).
    public let cashPnl: Decimal
    /// Unrealized profit/loss as a percentage (pre-computed by the API).
    public let percentPnl: Decimal
    /// Whether the position can be redeemed (market resolved in the holder's favor).
    public let redeemable: Bool

    /// Creates a position. Values mirror the Data API's pre-computed fields.
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

    /// Whether the position is at or above break-even (used to colour PnL green/red).
    public var isProfitable: Bool { cashPnl >= 0 }
}
