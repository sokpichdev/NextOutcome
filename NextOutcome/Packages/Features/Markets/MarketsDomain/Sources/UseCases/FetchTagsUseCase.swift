//
//  FetchTagsUseCase.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

public struct FetchTagsUseCase: Sendable {
    private let repository: MarketRepository

    public init(repository: MarketRepository) {
        self.repository = repository
    }

    public func execute() async throws -> [Tag] {
        try await repository.fetchTags()
    }

    /// Returns an instance whose `execute` always returns an empty array. Use in unit tests.
    #if DEBUG
    public static let stub = FetchTagsUseCase(repository: StubMarketRepository())
    #endif
}
