//
//  FetchLeaderboardUseCase.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

public struct FetchLeaderboardUseCase: Sendable {
    private let repository: PortfolioRepository

    public init(repository: PortfolioRepository) {
        self.repository = repository
    }

    public func execute(
        metric: LeaderboardMetric = .volume,
        window: LeaderboardWindow = .week
    ) async throws -> [LeaderboardEntry] {
        try await repository.leaderboard(metric: metric, window: window)
    }
}
