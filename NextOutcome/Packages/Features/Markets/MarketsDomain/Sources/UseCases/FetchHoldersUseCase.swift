//
//  FetchHoldersUseCase.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

/// Loads the top holders of a market's outcome tokens.
public struct FetchHoldersUseCase: Sendable {
    /// The market repository backing this use case.
    private let repository: MarketRepository

    /// Creates the use case.
    /// - Parameter repository: The market repository to fetch from.
    public init(repository: MarketRepository) {
        self.repository = repository
    }

    /// Fetches the top holders for a market's condition.
    /// - Parameter conditionId: The market condition to fetch holders for.
    /// - Returns: The top holders.
    public func execute(conditionId: String) async throws -> [Holder] {
        try await repository.holders(conditionId: conditionId)
    }
}
