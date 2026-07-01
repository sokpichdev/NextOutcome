//
//  FetchClosedPositionsUseCase.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

public struct FetchClosedPositionsUseCase: Sendable {
    private let repository: PortfolioRepository

    public init(repository: PortfolioRepository) {
        self.repository = repository
    }

    public func execute(address: String) async throws -> [ClosedPosition] {
        try await repository.closedPositions(address: address)
    }
}
