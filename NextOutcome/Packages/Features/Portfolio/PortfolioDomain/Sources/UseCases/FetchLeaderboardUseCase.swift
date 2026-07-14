//
//  FetchLeaderboardUseCase.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

/// Loads the trader leaderboard for a metric and window.
public struct FetchLeaderboardUseCase: Sendable {
    /// The data source for leaderboard data.
    private let repository: PortfolioRepository

    /// Creates the use case.
    /// - Parameter repository: The portfolio repository to fetch from.
    public init(repository: PortfolioRepository) {
        self.repository = repository
    }

    /// Fetches the leaderboard.
    /// - Parameters:
    ///   - metric: Rank by volume or profit. Defaults to volume.
    ///   - window: The time window. Defaults to the last week.
    ///   - category: A category slug (e.g. "esports") to scope rankings to. Defaults to
    ///     `nil` (the global leaderboard).
    ///   - limit: The maximum number of rows. Defaults to the original 10-row page.
    /// - Returns: The ranked leaderboard entries.
    /// - Throws: A networking error if the fetch fails.
    public func execute(
        metric: LeaderboardMetric = .volume,
        window: LeaderboardWindow = .week,
        category: String? = nil,
        limit: Int = 10
    ) async throws -> [LeaderboardEntry] {
        try await repository.leaderboard(metric: metric, window: window, category: category, limit: limit)
    }
}
