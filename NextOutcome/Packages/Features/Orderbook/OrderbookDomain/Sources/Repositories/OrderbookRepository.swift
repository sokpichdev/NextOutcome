//
//  OrderbookRepository.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

/// REST reads for the CLOB order book and historical prices.
public protocol OrderbookRepository: Sendable {
    /// One-shot order-book snapshot (used before the socket's first `book` arrives).
    func book(assetID: String) async throws -> OrderBook
    /// Historical price series for the chart.
    func priceHistory(assetID: String, interval: PriceHistoryInterval) async throws -> [PriceHistoryPoint]
}

/// Realtime port: a reconnecting stream of normalized book events for one token.
/// The concrete socket lives in the Data layer; Domain only sees this protocol.
public protocol MarketStreaming: Sendable {
    func events(assetID: String) -> AsyncStream<OrderBookEvent>
}
