//
//  FetchActivityTradesUseCase.swift
//  NextOutcome
//
//  Created by Sok Pich on 03/07/2026.
//

/// Loads recent trades for a market, shown in the event-detail social strip.
public struct FetchActivityTradesUseCase: Sendable {
    /// The market repository backing this use case.
    private let repository: MarketRepository

    /// Creates the use case.
    /// - Parameter repository: The market repository to fetch from.
    public init(repository: MarketRepository) {
        self.repository = repository
    }

    /// Fetches recent trades for a market's condition.
    /// - Parameter conditionId: The market condition to fetch trades for.
    /// - Returns: The recent trades.
    public func execute(conditionId: String) async throws -> [ActivityTrade] {
        try await repository.trades(conditionId: conditionId)
    }

    /// A stub instance (backed by an empty repository) for previews/tests.
    #if DEBUG
    public static let stub = FetchActivityTradesUseCase(repository: StubMarketRepository())
    #endif
}
