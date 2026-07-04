//
//  FetchGameResultsUseCase.swift
//  NextOutcome
//
//  Created by Sok Pich on 04/07/2026.
//

public struct FetchGameResultsUseCase: Sendable {
    private let repository: MarketRepository

    public init(repository: MarketRepository) {
        self.repository = repository
    }

    public func execute(eventIDs: [String]) async throws -> [String: GameResult] {
        guard !eventIDs.isEmpty else { return [:] }
        return try await repository.fetchGameResults(eventIDs: eventIDs)
    }

    /// Returns an instance whose `execute` always returns no results. Use in unit tests.
    #if DEBUG
    public static let stub = FetchGameResultsUseCase(repository: StubMarketRepository())
    #endif
}
