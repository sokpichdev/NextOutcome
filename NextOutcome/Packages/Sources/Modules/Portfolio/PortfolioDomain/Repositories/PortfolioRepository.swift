//
//  PortfolioRepository.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import Foundation
import SharedDomain

/// Watch-only reads from the Data API. No signing, no custody.
public protocol PortfolioRepository: Sendable {
    /// Fetches the open positions for a wallet.
    func positions(address: String) async throws -> [Position]
    /// Fetches the total portfolio value (in dollars) for a wallet.
    func value(address: String) async throws -> Decimal
    /// Fetches a page of the wallet's activity feed.
    /// - Parameters:
    ///   - address: The wallet address.
    ///   - cursor: The pagination cursor, or `nil` for the first page.
    func activity(address: String, cursor: String?) async throws -> Page<Activity>
    /// Fetches the wallet's settled/closed positions.
    func closedPositions(address: String) async throws -> [ClosedPosition]
    /// Fetches the leaderboard for a metric and time window, optionally scoped to a
    /// category (e.g. "esports").
    /// - Parameters:
    ///   - metric: Rank by volume or profit.
    ///   - window: The time window.
    ///   - category: The Polymarket category slug to scope rankings to, or `nil` for global.
    ///   - limit: The maximum number of entries to return.
    func leaderboard(
        metric: LeaderboardMetric, window: LeaderboardWindow, category: String?, limit: Int
    ) async throws -> [LeaderboardEntry]
}

public extension PortfolioRepository {
    /// Fetches the global leaderboard (no category scope) with the original 10-row page.
    func leaderboard(metric: LeaderboardMetric, window: LeaderboardWindow) async throws -> [LeaderboardEntry] {
        try await leaderboard(metric: metric, window: window, category: nil, limit: 10)
    }
}
