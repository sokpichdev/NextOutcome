//
//  OrderBookEvent.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import Foundation

public enum BookSide: Sendable, Hashable {
    case bid
    case ask
}

/// A single price/size mutation. `size == 0` removes the level.
public struct LevelChange: Sendable, Hashable {
    public let side: BookSide
    public let price: Decimal
    public let size: Decimal

    public init(side: BookSide, price: Decimal, size: Decimal) {
        self.side = side
        self.price = price
        self.size = size
    }
}

/// Socket connection lifecycle, as observed by `MarketSocket` (which owns all
/// reconnect/backoff timing). Consumers only ever *observe* this — never reimplement it.
public enum ConnectionState: Sendable, Equatable {
    case connecting
    case live
    case reconnecting
}

/// Normalized events from the market WebSocket, ready for the pure reducer.
public enum OrderBookEvent: Sendable {
    case snapshot(bids: [PriceLevel], asks: [PriceLevel], tickSize: Decimal?, lastTrade: Decimal?)
    case priceChanges([LevelChange])
    case lastTrade(Decimal)
    case tickSize(Decimal)
    /// Socket dropped/reconnected. Carries no book data — the reducer passes the book
    /// through unchanged; only connection-status observers care about this case.
    case connectionState(ConnectionState)
}
