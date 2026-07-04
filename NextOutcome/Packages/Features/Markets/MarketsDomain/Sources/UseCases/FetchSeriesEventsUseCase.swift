//
//  FetchSeriesEventsUseCase.swift
//  NextOutcome
//
//  Created by Sok Pich on 04/07/2026.
//

import SharedDomain

public struct FetchSeriesEventsUseCase: Sendable {
    private let repository: MarketRepository

    public init(repository: MarketRepository) {
        self.repository = repository
    }

    public func execute(seriesID: String, status: EventStatus = .active) async throws -> [Event] {
        try await repository.fetchEvents(seriesID: seriesID, status: status)
    }

    /// Returns an instance whose `execute` always returns no events. Use in unit tests.
    #if DEBUG
    public static let stub = FetchSeriesEventsUseCase(repository: StubMarketRepository())
    #endif
}
