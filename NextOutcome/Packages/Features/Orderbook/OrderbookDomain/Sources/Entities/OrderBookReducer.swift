//
//  OrderBookReducer.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import Foundation

/// Pure book reconciliation: `snapshot` replaces, `priceChanges` upsert/remove levels,
/// keeping bids high→low and asks low→high. No I/O — trivially unit-testable.
public enum OrderBookReducer {

    public static func reduce(_ book: OrderBook, _ event: OrderBookEvent) -> OrderBook {
        switch event {
        case let .snapshot(bids, asks, tickSize, lastTrade):
            return OrderBook(
                assetID: book.assetID,
                bids: sortedBids(bids),
                asks: sortedAsks(asks),
                lastTradePrice: lastTrade ?? book.lastTradePrice,
                tickSize: tickSize ?? book.tickSize
            )

        case let .priceChanges(changes):
            var bids = Dictionary(uniqueKeysWithValues: book.bids.map { ($0.price, $0.size) })
            var asks = Dictionary(uniqueKeysWithValues: book.asks.map { ($0.price, $0.size) })
            for change in changes {
                apply(change, bids: &bids, asks: &asks)
            }
            return OrderBook(
                assetID: book.assetID,
                bids: sortedBids(levels(from: bids)),
                asks: sortedAsks(levels(from: asks)),
                lastTradePrice: book.lastTradePrice,
                tickSize: book.tickSize
            )

        case let .lastTrade(price):
            return OrderBook(
                assetID: book.assetID, bids: book.bids, asks: book.asks,
                lastTradePrice: price, tickSize: book.tickSize
            )

        case let .tickSize(size):
            return OrderBook(
                assetID: book.assetID, bids: book.bids, asks: book.asks,
                lastTradePrice: book.lastTradePrice, tickSize: size
            )

        case .connectionState:
            // No book data — connection lifecycle is observed separately.
            return book
        }
    }

    private static func apply(
        _ change: LevelChange,
        bids: inout [Decimal: Decimal],
        asks: inout [Decimal: Decimal]
    ) {
        let removing = change.size <= 0
        switch change.side {
        case .bid:
            if removing { bids[change.price] = nil } else { bids[change.price] = change.size }
        case .ask:
            if removing { asks[change.price] = nil } else { asks[change.price] = change.size }
        }
    }

    private static func levels(from map: [Decimal: Decimal]) -> [PriceLevel] {
        map.map { PriceLevel(price: $0.key, size: $0.value) }
    }

    private static func sortedBids(_ levels: [PriceLevel]) -> [PriceLevel] {
        levels.filter { $0.size > 0 }.sorted { $0.price > $1.price }
    }

    private static func sortedAsks(_ levels: [PriceLevel]) -> [PriceLevel] {
        levels.filter { $0.size > 0 }.sorted { $0.price < $1.price }
    }
}
