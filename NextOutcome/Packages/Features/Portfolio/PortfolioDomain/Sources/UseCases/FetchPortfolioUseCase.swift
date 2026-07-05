//
//  FetchPortfolioUseCase.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import Foundation

/// Loads total value and open positions concurrently, returning one aggregate.
public struct FetchPortfolioUseCase: Sendable {
    /// The data source for positions and value.
    private let repository: PortfolioRepository

    /// Creates the use case.
    /// - Parameter repository: The portfolio repository to fetch from.
    public init(repository: PortfolioRepository) {
        self.repository = repository
    }

    /// Loads the wallet's value and positions in parallel and combines them.
    ///
    /// The two fetches run concurrently with `async let` so the screen loads roughly as
    /// fast as the slower of the two requests, not their sum.
    /// - Parameter address: The wallet to load.
    /// - Returns: The combined `Portfolio` snapshot.
    /// - Throws: A networking error if either fetch fails.
    public func execute(address: String) async throws -> Portfolio {
        async let positions = repository.positions(address: address)
        async let value = repository.value(address: address)
        return try await Portfolio(address: address, value: value, positions: positions)
    }
}
