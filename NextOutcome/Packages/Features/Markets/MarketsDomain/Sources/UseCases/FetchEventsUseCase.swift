//
//  FetchEventsUseCase.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import SharedDomain

/// Loads a page of events for the main feed, with optional tag filter and sort.
public struct FetchEventsUseCase: Sendable {
    /// The market repository backing this use case.
    private let repository: MarketRepository

    /// Creates the use case.
    /// - Parameter repository: The market repository to fetch from.
    public init(repository: MarketRepository) {
        self.repository = repository
    }

    /// Fetches one page of events.
    /// - Parameters:
    ///   - cursor: The pagination cursor, or `nil` for the first page.
    ///   - tagID: An optional category tag to filter by.
    ///   - sort: The sort order. Defaults to 24-hour volume.
    ///   - status: Which events to include. Defaults to active only.
    /// - Returns: A page of events plus the next cursor.
    public func execute(cursor: String? = nil, tagID: String? = nil, sort: EventSort = .volume24h, status: EventStatus = .active) async throws -> Page<Event> {
        try await repository.fetchEvents(cursor: cursor, tagID: tagID, sort: sort, status: status)
    }

    /// Returns an instance whose `execute` always returns an empty page. Use in unit tests.
    #if DEBUG
    public static let stub = FetchEventsUseCase(repository: StubMarketRepository())
    #endif
}
