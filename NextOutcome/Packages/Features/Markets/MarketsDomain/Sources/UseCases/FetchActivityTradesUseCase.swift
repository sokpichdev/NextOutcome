//
//  FetchActivityTradesUseCase.swift
//  NextOutcome
//
//  Created by Sok Pich on 03/07/2026.
//

public struct FetchActivityTradesUseCase: Sendable {
    private let repository: MarketRepository

    public init(repository: MarketRepository) {
        self.repository = repository
    }

    public func execute(conditionId: String) async throws -> [ActivityTrade] {
        try await repository.trades(conditionId: conditionId)
    }

    #if DEBUG
    public static let stub = FetchActivityTradesUseCase(repository: StubMarketRepository())
    #endif
}
