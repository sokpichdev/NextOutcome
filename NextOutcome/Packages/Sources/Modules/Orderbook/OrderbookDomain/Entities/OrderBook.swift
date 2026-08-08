//
//  OrderBook.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import Foundation

/// One price level. `size == 0` means the level is empty (removed).
public struct PriceLevel: Hashable, Sendable {
    /// The price of this level, as a probability (0…1).
    public let price: Decimal
    /// The total resting size (shares) at this price. `0` means the level is gone.
    public let size: Decimal

    /// Creates a price level.
    /// - Parameters:
    ///   - price: The level's price (0…1).
    ///   - size: The resting size at that price.
    public init(price: Decimal, size: Decimal) {
        self.price = price
        self.size = size
    }
}

/// Reconciled order book for a single CLOB token (`assetID`).
/// `bids` are kept sorted high→low, `asks` low→high.
public struct OrderBook: Hashable, Sendable {
    /// The CLOB token this book belongs to.
    public let assetID: String
    /// Buy orders, sorted highest price first (best bid at index 0).
    public let bids: [PriceLevel]
    /// Sell orders, sorted lowest price first (best ask at index 0).
    public let asks: [PriceLevel]
    /// The price of the most recent trade, if known.
    public let lastTradePrice: Decimal?
    /// The market's minimum price increment, if known.
    public let tickSize: Decimal?

    /// Creates an order book. Defaults produce an empty book you can reduce events onto.
    /// - Parameters:
    ///   - assetID: The token this book is for.
    ///   - bids: Buy levels (high→low).
    ///   - asks: Sell levels (low→high).
    ///   - lastTradePrice: The last traded price, if any.
    ///   - tickSize: The price tick size, if known.
    public init(
        assetID: String,
        bids: [PriceLevel] = [],
        asks: [PriceLevel] = [],
        lastTradePrice: Decimal? = nil,
        tickSize: Decimal? = nil
    ) {
        self.assetID = assetID
        self.bids = bids
        self.asks = asks
        self.lastTradePrice = lastTradePrice
        self.tickSize = tickSize
    }

    /// The highest price someone is willing to buy at, or `nil` if there are no bids.
    public var bestBid: Decimal? { bids.first?.price }
    /// The lowest price someone is willing to sell at, or `nil` if there are no asks.
    public var bestAsk: Decimal? { asks.first?.price }

    /// The gap between the best ask and best bid, or `nil` if either side is empty.
    public var spread: Decimal? {
        guard let bid = bestBid, let ask = bestAsk else { return nil }
        return ask - bid
    }

    /// The price halfway between the best bid and best ask — a common "fair value"
    /// estimate. `nil` if either side is empty.
    public var midpoint: Decimal? {
        guard let bid = bestBid, let ask = bestAsk else { return nil }
        return (bid + ask) / 2
    }

    /// Whether the book has no orders on either side.
    public var isEmpty: Bool { bids.isEmpty && asks.isEmpty }
}
