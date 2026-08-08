//
//  ClobOrderbookRepository.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import Foundation
import Networking
import OrderbookDomain

/// The live implementation of `OrderbookRepository`, backed by Polymarket's CLOB and data
/// REST APIs. Each method builds an `Endpoint`, fetches via the shared `APIClient`, and
/// maps the DTO into domain types with `OrderbookMapper`.
public struct ClobOrderbookRepository: OrderbookRepository {
    /// The shared API client used for all requests.
    private let client: APIClient

    /// Creates the repository.
    /// - Parameter client: The shared `APIClient`.
    public init(client: APIClient) {
        self.client = client
    }

    /// Fetches a one-shot order-book snapshot for a token from CLOB `GET /book`.
    public func book(assetID: String) async throws -> OrderBook {
        let endpoint = Endpoint(host: .clob, path: "/book", query: ["token_id": assetID])
        let dto: ClobBookDTO = try await client.fetch(endpoint)
        return OrderbookMapper.book(from: dto, assetID: assetID)
    }

    /// Fetches the price-history series from CLOB `GET /prices-history`.
    /// - Parameters:
    ///   - assetID: The token to fetch history for.
    ///   - interval: The time window.
    /// - Returns: The parsed history points.
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

    /// Fetches authoritative server time from CLOB `GET /time`.
    public func serverTime() async throws -> Date {
        // CLOB `GET /time` returns a bare epoch-seconds integer (e.g. `1783008640`).
        let endpoint = Endpoint(host: .clob, path: "/time")
        let epoch: Double = try await client.fetch(endpoint)
        return Date(timeIntervalSince1970: epoch)
    }

    /// Fetches recent executed trades for an event from data `GET /trades`.
    /// - Parameters:
    ///   - eventID: The event to fetch trades for.
    ///   - limit: The maximum number of trades to return.
    /// - Returns: The parsed recent trades.
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
