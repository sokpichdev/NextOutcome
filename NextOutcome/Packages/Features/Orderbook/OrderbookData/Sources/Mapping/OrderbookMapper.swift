//
//  OrderbookMapper.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import Foundation
import OrderbookDomain

enum OrderbookMapper {

    // MARK: REST

    static func book(from dto: ClobBookDTO, assetID: String) -> OrderBook {
        OrderBook(
            assetID: dto.assetId ?? assetID,
            bids: sortedBids(dto.bids?.compactMap(level(from:)) ?? []),
            asks: sortedAsks(dto.asks?.compactMap(level(from:)) ?? []),
            lastTradePrice: dto.lastTradePrice.flatMap { Decimal(string: $0) },
            tickSize: dto.tickSize.flatMap { Decimal(string: $0) }
        )
    }

    static func priceHistory(from dto: PriceHistoryDTO) -> [PriceHistoryPoint] {
        dto.history.map {
            PriceHistoryPoint(date: Date(timeIntervalSince1970: $0.t), price: Decimal($0.p))
        }
    }

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

    private static func level(from dto: ClobLevelDTO) -> PriceLevel? {
        guard let price = Decimal(string: dto.price), let size = Decimal(string: dto.size) else { return nil }
        return PriceLevel(price: price, size: size)
    }

    private static func level(from dto: WSLevelDTO) -> PriceLevel? {
        guard let price = Decimal(string: dto.price), let size = Decimal(string: dto.size) else { return nil }
        return PriceLevel(price: price, size: size)
    }

    private static func change(from dto: WSChangeDTO) -> LevelChange? {
        guard let price = Decimal(string: dto.price), let size = Decimal(string: dto.size) else { return nil }
        return LevelChange(side: side(from: dto.side), price: price, size: size)
    }

    private static func singleChange(from message: MarketMessageDTO) -> LevelChange? {
        guard let side = message.side,
              let priceRaw = message.price, let price = Decimal(string: priceRaw),
              let sizeRaw = message.size, let size = Decimal(string: sizeRaw) else { return nil }
        return LevelChange(side: self.side(from: side), price: price, size: size)
    }

    private static func side(from raw: String) -> BookSide {
        raw.uppercased() == "SELL" ? .ask : .bid
    }

    private static func sortedBids(_ levels: [PriceLevel]) -> [PriceLevel] {
        levels.filter { $0.size > 0 }.sorted { $0.price > $1.price }
    }

    private static func sortedAsks(_ levels: [PriceLevel]) -> [PriceLevel] {
        levels.filter { $0.size > 0 }.sorted { $0.price < $1.price }
    }
}
