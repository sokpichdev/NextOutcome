//
//  SearchMarketsUseCase.swift
//  NextOutcome
//
//  Created by Sok Pich on 30/06/2026.
//

/// Runs a text search over markets, short-circuiting on an empty query.
public struct SearchMarketsUseCase: Sendable {
    /// The market repository backing this use case.
    private let repository: MarketRepository

    /// Creates the use case.
    /// - Parameter repository: The market repository to search.
    public init(repository: MarketRepository) {
        self.repository = repository
    }

    /// Searches markets by text. Returns an empty array for a blank query rather than
    /// hitting the network.
    /// - Parameter query: The search text.
    /// - Returns: The matching markets.
    public func execute(query: String) async throws -> [Market] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        return try await repository.searchMarkets(query: query)
    }
}
