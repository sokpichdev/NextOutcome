//
//  ClobOrderbookRepository.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import Foundation
import Networking
import OrderbookDomain

public struct ClobOrderbookRepository: OrderbookRepository {
    private let client: APIClient

    public init(client: APIClient) {
        self.client = client
    }

    public func book(assetID: String) async throws -> OrderBook {
        let endpoint = Endpoint(host: .clob, path: "/book", query: ["token_id": assetID])
        let dto: ClobBookDTO = try await client.fetch(endpoint)
        return OrderbookMapper.book(from: dto, assetID: assetID)
    }

    public func priceHistory(
        assetID: String,
        interval: PriceHistoryInterval
    ) async throws -> [PriceHistoryPoint] {
        let endpoint = Endpoint(
            host: .clob,
            path: "/prices-history",
            query: ["market": assetID, "interval": interval.rawValue, "fidelity": "10"]
        )
        let dto: PriceHistoryDTO = try await client.fetch(endpoint)
        return OrderbookMapper.priceHistory(from: dto)
    }

    public func serverTime() async throws -> Date {
        // CLOB `GET /time` returns a bare epoch-seconds integer (e.g. `1783008640`).
        let endpoint = Endpoint(host: .clob, path: "/time")
        let epoch: Double = try await client.fetch(endpoint)
        return Date(timeIntervalSince1970: epoch)
    }

    public func recentTrades(eventID: String, limit: Int) async throws -> [RecentTrade] {
        let endpoint = Endpoint(
            host: .data,
            path: "/trades",
            query: ["eventId": eventID, "limit": String(limit), "offset": "0"]
        )
        let dtos: [TradeDTO] = try await client.fetch(endpoint)
        return OrderbookMapper.recentTrades(from: dtos)
    }
}
