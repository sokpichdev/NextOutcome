//
//  FetchCompletedEventsUseCase.swift
//  NextOutcome
//
//  Created by Sok Pich on 04/07/2026.
//

/// Loads the most-recently-finished events of a series (e.g. the last knockout round).
public struct FetchCompletedEventsUseCase: Sendable {
    /// The market repository backing this use case.
    private let repository: MarketRepository

    /// Creates the use case.
    /// - Parameter repository: The market repository to fetch from.
    public init(repository: MarketRepository) {
        self.repository = repository
    }

    /// Fetches completed events for a series, newest first.
    /// - Parameters:
    ///   - seriesID: The series (tournament) id.
    ///   - limit: The maximum number of events to return. Defaults to 60.
    /// - Returns: The completed events.
    public func execute(seriesID: String, limit: Int = 60) async throws -> [Event] {
        try await repository.fetchCompletedEvents(seriesID: seriesID, limit: limit)
    }

    /// A stub instance (backed by an empty repository) for previews/tests.
    #if DEBUG
    public static let stub = FetchCompletedEventsUseCase(repository: StubMarketRepository())
    #endif
}
