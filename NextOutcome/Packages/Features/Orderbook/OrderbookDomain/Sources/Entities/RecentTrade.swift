//
//  RecentTrade.swift
//  NextOutcome
//

import Foundation

/// One executed trade for the live recent-trades ticker (from the data `/trades` feed).
public struct RecentTrade: Hashable, Sendable, Identifiable {
    /// Whether the trade was a buy or a sell.
    public enum Side: String, Sendable {
        /// A buy.
        case buy
        /// A sell.
        case sell
    }

    /// Stable unique ID (used by SwiftUI `ForEach` and to de-dupe).
    public let id: String
    /// Buy or sell.
    public let side: Side
    /// The executed price, as a probability (0…1).
    public let price: Decimal   // 0…1
    /// The number of shares traded.
    public let size: Decimal
    /// The outcome name that was traded (e.g. "Yes", a team name).
    public let outcome: String
    /// When the trade executed.
    public let timestamp: Date

    /// Creates a recent-trade record.
    public init(
        id: String,
        side: Side,
        price: Decimal,
        size: Decimal,
        outcome: String,
        timestamp: Date
    ) {
        self.id = id
        self.side = side
        self.price = price
        self.size = size
        self.outcome = outcome
        self.timestamp = timestamp
    }
}
