//
//  RecentTrade.swift
//  NextOutcome
//

import Foundation

/// One executed trade for the live recent-trades ticker (from the data `/trades` feed).
public struct RecentTrade: Hashable, Sendable, Identifiable {
    public enum Side: String, Sendable {
        case buy
        case sell
    }

    public let id: String
    public let side: Side
    public let price: Decimal   // 0…1
    public let size: Decimal
    public let outcome: String
    public let timestamp: Date

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
