//
//  FetchEventUseCase.swift
//  NextOutcome
//
//  Created by Sok Pich on 04/07/2026.
//

/// Loads a single event by its URL slug (e.g. for a deep link or detail screen).
public struct FetchEventUseCase: Sendable {
    /// The market repository backing this use case.
    private let repository: MarketRepository

    /// Creates the use case.
    /// - Parameter repository: The market repository to fetch from.
    public init(repository: MarketRepository) {
        self.repository = repository
    }

    /// Fetches one event.
    /// - Parameter slug: The event's URL slug.
    /// - Returns: The event.
    public func execute(slug: String) async throws -> Event {
        try await repository.fetchEvent(slug: slug)
    }

    /// Returns an instance whose `execute` always throws. Use in unit tests.
    #if DEBUG
    public static let stub = FetchEventUseCase(repository: StubMarketRepository())
    #endif
}
