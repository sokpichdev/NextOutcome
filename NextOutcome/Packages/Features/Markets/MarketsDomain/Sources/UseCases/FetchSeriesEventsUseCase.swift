//
//  FetchSeriesEventsUseCase.swift
//  NextOutcome
//
//  Created by Sok Pich on 04/07/2026.
//

import SharedDomain

/// Loads all events of a Gamma series (e.g. a whole tournament), unpaginated.
public struct FetchSeriesEventsUseCase: Sendable {
    /// The market repository backing this use case.
    private let repository: MarketRepository

    /// Creates the use case.
    /// - Parameter repository: The market repository to fetch from.
    public init(repository: MarketRepository) {
        self.repository = repository
    }

    /// Fetches a series' events.
    /// - Parameters:
    ///   - seriesID: The series id.
    ///   - status: Which events to include. Defaults to active only.
    /// - Returns: The series' events.
    public func execute(seriesID: String, status: EventStatus = .active) async throws -> [Event] {
        try await repository.fetchEvents(seriesID: seriesID, status: status)
    }

    /// Returns an instance whose `execute` always returns no events. Use in unit tests.
    #if DEBUG
    public static let stub = FetchSeriesEventsUseCase(repository: StubMarketRepository())
    #endif
}
