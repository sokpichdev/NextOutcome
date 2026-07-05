//
//  FetchClosedPositionsUseCase.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

/// Loads a wallet's settled/closed positions.
public struct FetchClosedPositionsUseCase: Sendable {
    /// The data source for closed positions.
    private let repository: PortfolioRepository

    /// Creates the use case.
    /// - Parameter repository: The portfolio repository to fetch from.
    public init(repository: PortfolioRepository) {
        self.repository = repository
    }

    /// Fetches the wallet's closed positions.
    /// - Parameter address: The wallet to load.
    /// - Returns: The closed positions.
    /// - Throws: A networking error if the fetch fails.
    public func execute(address: String) async throws -> [ClosedPosition] {
        try await repository.closedPositions(address: address)
    }
}
