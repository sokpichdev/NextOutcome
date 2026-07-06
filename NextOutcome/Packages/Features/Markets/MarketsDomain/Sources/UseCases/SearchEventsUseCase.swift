//
//  SearchEventsUseCase.swift
//  NextOutcome
//

import Foundation

/// Runs a text search over events, short-circuiting on an empty query.
public struct SearchEventsUseCase: Sendable {
    /// The market repository backing this use case.
    private let repository: MarketRepository

    /// Creates the use case.
    /// - Parameter repository: The market repository to search.
    public init(repository: MarketRepository) {
        self.repository = repository
    }

    /// Searches events by text. Returns an empty array for a blank query rather than
    /// hitting the network.
    /// - Parameter query: The search text.
    /// - Returns: The matching events.
    public func execute(query: String) async throws -> [Event] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        return try await repository.searchEvents(query: query)
    }

    /// Returns an instance whose `execute` always returns an empty array. Use in unit tests.
    #if DEBUG
    public static let stub = SearchEventsUseCase(repository: StubMarketRepository())
    #endif
}
