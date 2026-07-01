//
//  OrderBook.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import Foundation

/// One price level. `size == 0` means the level is empty (removed).
public struct PriceLevel: Hashable, Sendable {
    public let price: Decimal
    public let size: Decimal

    public init(price: Decimal, size: Decimal) {
        self.price = price
        self.size = size
    }
}

/// Reconciled order book for a single CLOB token (`assetID`).
/// `bids` are kept sorted high→low, `asks` low→high.
public struct OrderBook: Hashable, Sendable {
    public let assetID: String
    public let bids: [PriceLevel]
    public let asks: [PriceLevel]
    public let lastTradePrice: Decimal?
    public let tickSize: Decimal?

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

    public var bestBid: Decimal? { bids.first?.price }
    public var bestAsk: Decimal? { asks.first?.price }

    public var spread: Decimal? {
        guard let bid = bestBid, let ask = bestAsk else { return nil }
        return ask - bid
    }

    public var midpoint: Decimal? {
        guard let bid = bestBid, let ask = bestAsk else { return nil }
        return (bid + ask) / 2
    }

    public var isEmpty: Bool { bids.isEmpty && asks.isEmpty }
}
