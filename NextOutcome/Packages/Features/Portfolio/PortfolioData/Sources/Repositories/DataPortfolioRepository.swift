//
//  DataPortfolioRepository.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import Foundation
import Networking
import PortfolioDomain
import SharedDomain

/// The live implementation of `PortfolioRepository`, backed by Polymarket's Data API. This
/// is watch-only: it reads a wallet's positions, value, activity, and rankings, but never
/// signs or holds funds. Each method builds an `Endpoint`, fetches via `APIClient`, and
/// maps DTOs into domain types.
public struct DataPortfolioRepository: PortfolioRepository {
    /// Page size for the activity feed's cursor pagination.
    private static let pageSize = 10
    /// The shared API client used for all requests.
    private let client: APIClient

    /// Creates the repository.
    /// - Parameter client: The shared `APIClient`.
    public init(client: APIClient) {
        self.client = client
    }

    /// Fetches open positions above a small dust threshold from `/positions`.
    public func positions(address: String) async throws -> [Position] {
        let endpoint = Endpoint(
            host: .data,
            path: "/positions",
            query: ["user": address, "sizeThreshold": "0.1", "limit": "100"]
        )
        let dtos: [PositionDTO] = try await client.fetch(endpoint)
        return dtos.map(PositionMapper.position(from:))
    }

    /// Fetches the total portfolio value from `/value`, tolerating both the array and
    /// single-object response shapes the API can return.
    public func value(address: String) async throws -> Decimal {
        let endpoint = Endpoint(host: .data, path: "/value", query: ["user": address])
        // `/value` may return an array of rows or a single object.
        if let rows: [PortfolioValueDTO] = try? await client.fetch(endpoint) {
            return rows.first?.value ?? 0
        }
        let single: PortfolioValueDTO = try await client.fetch(endpoint)
        return single.value
    }

    /// Fetches one page of activity from `/activity`, translating the `cursor` to an offset
    /// and computing the next cursor when a full page comes back.
    /// - Parameters:
    ///   - address: The wallet address.
    ///   - cursor: The offset cursor, or `nil` for the first page.
    /// - Returns: A page of activity plus the next cursor (or `nil` at the end).
    public func activity(address: String, cursor: String?) async throws -> Page<Activity> {
        let offset = cursor.flatMap(Int.init) ?? 0
        let endpoint = Endpoint(
            host: .data,
            path: "/activity",
            query: ["user": address, "limit": "\(Self.pageSize)", "offset": "\(offset)"]
        )
        let dtos: [ActivityDTO] = try await client.fetch(endpoint)
        let items = dtos.enumerated().map { ActivityMapper.activity(from: $1, index: offset + $0) }
        let nextCursor = dtos.count == Self.pageSize ? "\(offset + Self.pageSize)" : nil
        return Page(items: items, nextCursor: nextCursor)
    }

    /// Fetches settled positions from `/closed-positions`.
    public func closedPositions(address: String) async throws -> [ClosedPosition] {
        let endpoint = Endpoint(
            host: .data,
            path: "/closed-positions",
            query: ["user": address, "limit": "100"]
        )
        let dtos: [ClosedPositionDTO] = try await client.fetch(endpoint)
        return dtos.enumerated().map { LeaderboardMapper.closedPosition(from: $1, index: $0) }
    }

    /// Fetches the leaderboard from `/v1/leaderboard`, assigning 1-based ranks by position.
    /// - Parameters:
    ///   - metric: Rank by volume or profit.
    ///   - window: The time window.
    /// - Returns: The ranked entries.
    public func leaderboard(
        metric: LeaderboardMetric,
        window: LeaderboardWindow
    ) async throws -> [LeaderboardEntry] {
        let endpoint = Endpoint(
            host: .data,
            path: "/v1/leaderboard",
            query: ["rankBy": metric.rawValue, "window": window.rawValue, "limit": "10"]
        )
        let dtos: [LeaderboardEntryDTO] = try await client.fetch(endpoint)
        return dtos.enumerated().map { LeaderboardMapper.entry(from: $1, rank: $0 + 1) }
    }
}
