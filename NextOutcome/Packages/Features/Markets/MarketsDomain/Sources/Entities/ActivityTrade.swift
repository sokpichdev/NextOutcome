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

    public var label: String {
        switch self {
        case .buy: return "Buy"
        case .sell: return "Sell"
        }
    }
}

/// One filled trade against a market's outcome token, as shown in the Activity tab.
public struct ActivityTrade: Identifiable, Hashable, Sendable {
    public let id: String
    public let side: TradeSide
    public let actorName: String
    public let outcome: String
    public let size: Decimal
    public let price: Decimal
    public let timestamp: Date
    public let avatarURL: URL?

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
