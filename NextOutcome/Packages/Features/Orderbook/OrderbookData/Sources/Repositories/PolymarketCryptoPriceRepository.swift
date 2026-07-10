//
//  PolymarketCryptoPriceRepository.swift
//  NextOutcome
//
//  Created by Sok Pich on 11/07/2026.
//

import Foundation
import Networking
import OrderbookDomain

/// The live implementation of `CryptoSpotPriceRepository`, backed by polymarket.com's own
/// `/api/crypto/*` Next.js API routes — the same ones the web app uses to draw its
/// dollar-denominated price line and candlesticks. Unlike Gamma/Data/CLOB, these aren't a
/// dedicated API host; they're public reads on the main web host (`PolymarketService.web`).
public struct PolymarketCryptoPriceRepository: CryptoSpotPriceRepository {
    /// The shared API client used for all requests.
    private let client: APIClient

    /// Creates the repository.
    /// - Parameter client: The shared `APIClient`.
    public init(client: APIClient) {
        self.client = client
    }

    /// Fetches the spot-price series from `GET /api/crypto/price-history`.
    public func spotPriceHistory(
        symbol: String,
        eventStart: Date,
        eventEnd: Date
    ) async throws -> [CryptoSpotPricePoint] {
        let endpoint = Endpoint(
            host: .web,
            path: "/api/crypto/price-history",
            query: [
                "symbol": symbol,
                "eventStartTime": Self.iso8601.string(from: eventStart),
                "endDate": Self.iso8601.string(from: eventEnd),
                "variant": "fiveminute"
            ]
        )
        let dtos: [CryptoSpotPricePointDTO] = try await client.fetch(endpoint)
        return OrderbookMapper.spotPriceHistory(from: dtos)
    }

    /// Fetches the window's open/close snapshot from `GET /api/crypto/crypto-price`.
    public func priceWindow(
        symbol: String,
        eventStart: Date,
        eventEnd: Date
    ) async throws -> CryptoPriceWindow {
        let endpoint = Endpoint(
            host: .web,
            path: "/api/crypto/crypto-price",
            query: [
                "symbol": symbol,
                "eventStartTime": Self.iso8601.string(from: eventStart),
                "endDate": Self.iso8601.string(from: eventEnd),
                "variant": "fiveminute"
            ]
        )
        let dto: CryptoPriceWindowDTO = try await client.fetch(endpoint)
        return OrderbookMapper.priceWindow(from: dto)
    }

    /// Seconds-precision UTC ISO 8601 (e.g. `2026-07-03T15:30:00Z`), matching the exact
    /// shape the web app sends — no fractional seconds.
    private static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}
