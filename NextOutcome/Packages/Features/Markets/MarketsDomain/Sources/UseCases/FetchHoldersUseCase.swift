//
//  FetchHoldersUseCase.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

public struct FetchHoldersUseCase: Sendable {
    private let repository: MarketRepository

    public init(repository: MarketRepository) {
        self.repository = repository
    }

    public func execute(conditionId: String) async throws -> [Holder] {
        try await repository.holders(conditionId: conditionId)
    }
}
