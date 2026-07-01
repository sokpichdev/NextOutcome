//
//  FetchEventsUseCase.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import SharedDomain

public struct FetchEventsUseCase: Sendable {
    private let repository: MarketRepository
    
    public init(repository: MarketRepository) {
        self.repository = repository
    }
    
    public func execute(cursor: String? = nil, tagID: String? = nil) async throws -> Page<Event> {
        try await repository.fetchEvents(cursor: cursor, tagID: tagID)
    }

    /// Returns an instance whose `execute` always returns an empty page. Use in unit tests.
    public static let stub = FetchEventsUseCase(repository: StubMarketRepository())
}
