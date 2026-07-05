//
//  OrderBookEvent.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import Foundation

/// Which half of the book a change applies to.
public enum BookSide: Sendable, Hashable {
    /// The buy side.
    case bid
    /// The sell side.
    case ask
}

/// A single price/size mutation. `size == 0` removes the level.
public struct LevelChange: Sendable, Hashable {
    /// Which side of the book changed.
    public let side: BookSide
    /// The price level that changed.
    public let price: Decimal
    /// The new resting size at that level (`0` removes it).
    public let size: Decimal

    /// Creates a level change.
    /// - Parameters:
    ///   - side: Bid or ask.
    ///   - price: The affected price level.
    ///   - size: The new size at that level.
    public init(side: BookSide, price: Decimal, size: Decimal) {
        self.side = side
        self.price = price
        self.size = size
    }
}

/// Socket connection lifecycle, as observed by `MarketSocket` (which owns all
/// reconnect/backoff timing). Consumers only ever *observe* this — never reimplement it.
public enum ConnectionState: Sendable, Equatable {
    /// Establishing the connection for the first time.
    case connecting
    /// Connected and receiving updates.
    case live
    /// The connection dropped and is being re-established.
    case reconnecting
}

/// Normalized events from the market WebSocket, ready for the pure reducer.
public enum OrderBookEvent: Sendable {
    /// A full replacement of the book (the first message, or after a resync).
    case snapshot(bids: [PriceLevel], asks: [PriceLevel], tickSize: Decimal?, lastTrade: Decimal?)
    /// Incremental level updates to apply on top of the current book.
    case priceChanges([LevelChange])
    /// A new last-traded price.
    case lastTrade(Decimal)
    /// An updated tick size for the market.
    case tickSize(Decimal)
    /// Socket dropped/reconnected. Carries no book data — the reducer passes the book
    /// through unchanged; only connection-status observers care about this case.
    case connectionState(ConnectionState)
}
