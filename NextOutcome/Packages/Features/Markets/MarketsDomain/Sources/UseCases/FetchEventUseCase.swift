//
//  FetchEventUseCase.swift
//  NextOutcome
//
//  Created by Sok Pich on 04/07/2026.
//

public struct FetchEventUseCase: Sendable {
    private let repository: MarketRepository

    public init(repository: MarketRepository) {
        self.repository = repository
    }

    public func execute(slug: String) async throws -> Event {
        try await repository.fetchEvent(slug: slug)
    }

    /// Returns an instance whose `execute` always throws. Use in unit tests.
    #if DEBUG
    public static let stub = FetchEventUseCase(repository: StubMarketRepository())
    #endif
}
