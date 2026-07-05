//
//  ClosedPosition.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import Foundation

/// A settled/closed position. Slimmer than `Position` and carries realized PnL + a close time.
public struct ClosedPosition: Identifiable, Hashable, Sendable {
    /// Stable identity for the closed position.
    public let id: String
    /// The market title.
    public let title: String
    /// The market's URL slug.
    public let slug: String
    /// The outcome that was held.
    public let outcome: String
    /// The market's icon image, if any.
    public let iconURL: URL?
    /// Realized profit/loss in dollars.
    public let realizedPnl: Decimal
    /// Realized profit/loss as a percentage.
    public let percentRealizedPnl: Decimal
    /// When the position was closed.
    public let timestamp: Date

    /// Creates a closed-position record.
    public init(
        id: String, title: String, slug: String, outcome: String, iconURL: URL?,
        realizedPnl: Decimal, percentRealizedPnl: Decimal, timestamp: Date
    ) {
        self.id = id
        self.title = title
        self.slug = slug
        self.outcome = outcome
        self.iconURL = iconURL
        self.realizedPnl = realizedPnl
        self.percentRealizedPnl = percentRealizedPnl
        self.timestamp = timestamp
    }

    /// Whether the position closed at or above break-even.
    public var isProfitable: Bool { realizedPnl >= 0 }
}
