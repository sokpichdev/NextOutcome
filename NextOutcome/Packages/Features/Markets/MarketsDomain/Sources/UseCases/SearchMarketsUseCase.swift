//
//  SearchMarketsUseCase.swift
//  NextOutcome
//
//  Created by Sok Pich on 30/06/2026.
//

public struct SearchMarketsUseCase: Sendable {
    private let repository: MarketRepository
    
    public init(repository: MarketRepository) {
        self.repository = repository
    }
    
    public func execute(query: String) async throws -> [Market] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        return try await repository.searchMarkets(query: query)
    }
}
