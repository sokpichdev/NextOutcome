//
//  FetchAllEventsUseCase.swift
//  NextOutcome
//
//  Created by Sok Pich on 05/07/2026.
//

/// Loads all events under a Gamma tag (e.g. the Politics hub's "midterms" or "referendums"
/// tags), unpaginated.
public struct FetchAllEventsUseCase: Sendable {
    /// The market repository backing this use case.
    private let repository: MarketRepository

    /// Creates the use case.
    /// - Parameter repository: The market repository to fetch from.
    public init(repository: MarketRepository) {
        self.repository = repository
    }

    /// Fetches a tag's events.
    /// - Parameters:
    ///   - tagID: The tag id.
    ///   - status: Which events to include. Defaults to active only.
    /// - Returns: The tag's events.
    public func execute(tagID: String, status: EventStatus = .active) async throws -> [Event] {
        try await repository.fetchAllEvents(tagID: tagID, status: status)
    }

    /// Returns an instance whose `execute` always returns no events. Use in unit tests.
    #if DEBUG
    public static let stub = FetchAllEventsUseCase(repository: StubMarketRepository())
    #endif
}
