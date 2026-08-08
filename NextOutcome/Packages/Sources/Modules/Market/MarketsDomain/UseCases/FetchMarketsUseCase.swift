//
//  FetchMarketsUseCase.swift
//  NextOutcome
//
//  Created by Sok Pich on 30/06/2026.
//

import SharedDomain

/// Loads a page of individual markets.
public struct FetchMarketsUseCase: Sendable {
    /// The market repository backing this use case.
    private let repository: MarketRepository

    /// Creates the use case.
    /// - Parameter repository: The market repository to fetch from.
    public init(repository: MarketRepository) {
        self.repository = repository
    }

    /// Fetches one page of markets.
    /// - Parameter cursor: The pagination cursor, or `nil` for the first page.
    /// - Returns: A page of markets plus the next cursor.
    public func execute(cursor: String? = nil) async throws -> Page<Market> {
        try await repository.fetchMarkets(cursor: cursor)
    }
}
