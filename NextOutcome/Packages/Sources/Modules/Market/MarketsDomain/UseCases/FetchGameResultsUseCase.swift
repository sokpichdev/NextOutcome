//
//  FetchGameResultsUseCase.swift
//  NextOutcome
//
//  Created by Sok Pich on 04/07/2026.
//

/// Loads live/final scores for a batch of game events, keyed by event id.
public struct FetchGameResultsUseCase: Sendable {
    /// The market repository backing this use case.
    private let repository: MarketRepository

    /// Creates the use case.
    /// - Parameter repository: The market repository to fetch from.
    public init(repository: MarketRepository) {
        self.repository = repository
    }

    /// Fetches results for the given events. Short-circuits to empty when given no ids.
    /// - Parameter eventIDs: The event ids to fetch results for.
    /// - Returns: A dictionary of event id → result (missing ids are simply absent).
    public func execute(eventIDs: [String]) async throws -> [String: GameResult] {
        guard !eventIDs.isEmpty else { return [:] }
        return try await repository.fetchGameResults(eventIDs: eventIDs)
    }

    /// Returns an instance whose `execute` always returns no results. Use in unit tests.
    #if DEBUG
    public static let stub = FetchGameResultsUseCase(repository: StubMarketRepository())
    #endif
}
