//
//  OrderbookMapper.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import Foundation
import OrderbookDomain

/// Translates the network DTOs into clean domain types, parsing string-encoded numbers
/// into `Decimal` and normalizing the many WebSocket message shapes into a single stream
/// of `OrderBookEvent`s. Keeping this mapping in one place means the domain never sees the
/// API's quirks.
enum OrderbookMapper {

    // MARK: REST

    /// Maps a REST `/book` response into a reconciled `OrderBook`.
    /// - Parameters:
    ///   - dto: The decoded book response.
    ///   - assetID: The token requested, used as a fallback if the DTO omits it.
    /// - Returns: A sorted, parsed order book.
    static func book(from dto: ClobBookDTO, assetID: String) -> OrderBook {
        OrderBook(
            assetID: dto.assetId ?? assetID,
            bids: sortedBids(dto.bids?.compactMap(level(from:)) ?? []),
            asks: sortedAsks(dto.asks?.compactMap(level(from:)) ?? []),
            lastTradePrice: dto.lastTradePrice.flatMap { Decimal(string: $0) },
            tickSize: dto.tickSize.flatMap { Decimal(string: $0) }
        )
    }

    /// Maps a `/prices-history` response into domain history points.
    /// - Parameter dto: The decoded history response.
    /// - Returns: The parsed price-history points.
    static func priceHistory(from dto: PriceHistoryDTO) -> [PriceHistoryPoint] {
        dto.history.map {
            PriceHistoryPoint(date: Date(timeIntervalSince1970: $0.t), price: Decimal($0.p))
        }
    }

    /// Maps `/trades` DTOs into domain `RecentTrade`s, skipping any missing price/size and
    /// synthesizing a stable ID when the transaction hash is absent.
    /// - Parameter dtos: The decoded trades.
    /// - Returns: The parsed recent trades.
    static func recentTrades(from dtos: [TradeDTO]) -> [RecentTrade] {
        dtos.enumerated().compactMap { index, dto in
            guard let price = dto.price, let size = dto.size else { return nil }
            let ts = dto.timestamp ?? 0
            let id = dto.transactionHash
                ?? "\(dto.proxyWallet ?? "?")-\(Int(ts))-\(index)"
            return RecentTrade(
                id: id,
                side: dto.side?.uppercased() == "SELL" ? .sell : .buy,
                price: Decimal(price),
                size: Decimal(size),
                outcome: dto.outcome ?? "",
                timestamp: Date(timeIntervalSince1970: ts)
            )
        }
    }

    // MARK: WebSocket → normalized events

    /// Normalizes one raw market-channel message into zero or more `OrderBookEvent`s,
    /// switching on its `eventType`. Unknown or empty messages map to no events.
    /// - Parameter message: The decoded WebSocket message.
    /// - Returns: The events to feed into the reducer (possibly empty).
    static func events(from message: MarketMessageDTO) -> [OrderBookEvent] {
        switch message.eventType {
        case "book":
            return [.snapshot(
                bids: sortedBids(message.bids?.compactMap(level(from:)) ?? []),
                asks: sortedAsks(message.asks?.compactMap(level(from:)) ?? []),
                tickSize: message.tickSize.flatMap { Decimal(string: $0) },
                lastTrade: nil
            )]

        case "price_change":
            if let changes = message.changes, !changes.isEmpty {
                return [.priceChanges(changes.compactMap(change(from:)))]
            }
            if let single = singleChange(from: message) {
                return [.priceChanges([single])]
            }
            return []

        case "tick_size_change":
            guard let raw = message.newTickSize ?? message.tickSize,
                  let value = Decimal(string: raw) else { return [] }
            return [.tickSize(value)]

        case "last_trade_price":
            guard let raw = message.price, let value = Decimal(string: raw) else { return [] }
            return [.lastTrade(value)]

        default:
            return []
        }
    }

    // MARK: Helpers

    /// Parses a REST level DTO into a `PriceLevel`, or `nil` if either number is malformed.
    private static func level(from dto: ClobLevelDTO) -> PriceLevel? {
        guard let price = Decimal(string: dto.price), let size = Decimal(string: dto.size) else { return nil }
        return PriceLevel(price: price, size: size)
    }

    /// Parses a WebSocket level DTO into a `PriceLevel`, or `nil` if malformed.
    private static func level(from dto: WSLevelDTO) -> PriceLevel? {
        guard let price = Decimal(string: dto.price), let size = Decimal(string: dto.size) else { return nil }
        return PriceLevel(price: price, size: size)
    }

    /// Parses a WebSocket change DTO into a `LevelChange`, or `nil` if malformed.
    private static func change(from dto: WSChangeDTO) -> LevelChange? {
        guard let price = Decimal(string: dto.price), let size = Decimal(string: dto.size) else { return nil }
        return LevelChange(side: side(from: dto.side), price: price, size: size)
    }

    /// Builds a `LevelChange` from a message that carries a single change inline (rather
    /// than in the `changes` array), or `nil` if any field is missing/malformed.
    private static func singleChange(from message: MarketMessageDTO) -> LevelChange? {
        guard let side = message.side,
              let priceRaw = message.price, let price = Decimal(string: priceRaw),
              let sizeRaw = message.size, let size = Decimal(string: sizeRaw) else { return nil }
        return LevelChange(side: self.side(from: side), price: price, size: size)
    }

    /// Maps the API's "BUY"/"SELL" string to a `BookSide` (SELL → ask, anything else → bid).
    private static func side(from raw: String) -> BookSide {
        raw.uppercased() == "SELL" ? .ask : .bid
    }

    /// Drops empty levels and sorts bids highest price first.
    private static func sortedBids(_ levels: [PriceLevel]) -> [PriceLevel] {
        levels.filter { $0.size > 0 }.sorted { $0.price > $1.price }
    }

    /// Drops empty levels and sorts asks lowest price first.
    private static func sortedAsks(_ levels: [PriceLevel]) -> [PriceLevel] {
        levels.filter { $0.size > 0 }.sorted { $0.price < $1.price }
    }
}
