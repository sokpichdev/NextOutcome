//
//  ActivityTrade.swift
//  NextOutcome
//
//  Created by Sok Pich on 03/07/2026.
//

import Foundation

/// Side of a filled trade — drives the buy/sell color coding in the Activity tab.
public enum TradeSide: String, Sendable, Hashable {
    case buy, sell

    /// The human-readable label ("Buy"/"Sell") for the row.
    public var label: String {
        switch self {
        case .buy: return "Buy"
        case .sell: return "Sell"
        }
    }
}

/// One filled trade against a market's outcome token, as shown in the Activity tab.
public struct ActivityTrade: Identifiable, Hashable, Sendable {
    /// Stable identity for the trade row.
    public let id: String
    /// Buy or sell.
    public let side: TradeSide
    /// The trader's display name.
    public let actorName: String
    /// The outcome that was traded.
    public let outcome: String
    /// Number of shares traded.
    public let size: Decimal
    /// Price per share (0…1).
    public let price: Decimal
    /// When the trade happened.
    public let timestamp: Date
    /// The trader's avatar image, if any.
    public let avatarURL: URL?

    /// Creates an activity-trade row.
    public init(
        id: String, side: TradeSide, actorName: String, outcome: String,
        size: Decimal, price: Decimal, timestamp: Date, avatarURL: URL?
    ) {
        self.id = id
        self.side = side
        self.actorName = actorName
        self.outcome = outcome
        self.size = size
        self.price = price
        self.timestamp = timestamp
        self.avatarURL = avatarURL
    }
}
