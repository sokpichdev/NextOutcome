//
//  FetchActivityUseCase.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import SharedDomain

/// Loads a page of a wallet's activity feed.
public struct FetchActivityUseCase: Sendable {
    /// The data source for activity.
    private let repository: PortfolioRepository

    /// Creates the use case.
    /// - Parameter repository: The portfolio repository to fetch from.
    public init(repository: PortfolioRepository) {
        self.repository = repository
    }

    /// Fetches one page of activity.
    /// - Parameters:
    ///   - address: The wallet to load activity for.
    ///   - cursor: The pagination cursor, or `nil` for the first page.
    /// - Returns: A page of activity plus the next cursor.
    /// - Throws: A networking error if the fetch fails.
    public func execute(address: String, cursor: String? = nil) async throws -> Page<Activity> {
        try await repository.activity(address: address, cursor: cursor)
    }
}
