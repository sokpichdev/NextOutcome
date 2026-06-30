//
//  FetchMarketsUseCase.swift
//  NextOutcome
//
//  Created by Sok Pich on 30/06/2026.
//

import SharedDomain

public struct FetchMarketsUseCase: Sendable {
    private let repository: MarketRepository
    
    public init(repository: MarketRepository) {
        self.repository = repository
    }
    
    public func execute(cursor: String? = nil) async throws -> Page<Market> {
        try await repository.fetchMarkets(cursor: cursor)
    }
}
