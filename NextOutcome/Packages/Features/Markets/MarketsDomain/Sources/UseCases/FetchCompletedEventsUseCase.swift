//
//  FetchCompletedEventsUseCase.swift
//  NextOutcome
//
//  Created by Sok Pich on 04/07/2026.
//

public struct FetchCompletedEventsUseCase: Sendable {
    private let repository: MarketRepository

    public init(repository: MarketRepository) {
        self.repository = repository
    }

    public func execute(seriesID: String, limit: Int = 60) async throws -> [Event] {
        try await repository.fetchCompletedEvents(seriesID: seriesID, limit: limit)
    }

    #if DEBUG
    public static let stub = FetchCompletedEventsUseCase(repository: StubMarketRepository())
    #endif
}
