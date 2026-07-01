//
//  FetchPortfolioUseCase.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import Foundation

/// Loads total value and open positions concurrently, returning one aggregate.
public struct FetchPortfolioUseCase: Sendable {
    private let repository: PortfolioRepository

    public init(repository: PortfolioRepository) {
        self.repository = repository
    }

    public func execute(address: String) async throws -> Portfolio {
        async let positions = repository.positions(address: address)
        async let value = repository.value(address: address)
        return try await Portfolio(address: address, value: value, positions: positions)
    }
}
