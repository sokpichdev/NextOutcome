//
//  FetchTagsUseCase.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

/// Loads the category filter tags shown in the chip row.
public struct FetchTagsUseCase: Sendable {
    /// The market repository backing this use case.
    private let repository: MarketRepository

    /// Creates the use case.
    /// - Parameter repository: The market repository to fetch from.
    public init(repository: MarketRepository) {
        self.repository = repository
    }

    /// Fetches the filter tags.
    /// - Returns: The available tags.
    public func execute() async throws -> [Tag] {
        try await repository.fetchTags()
    }

    /// Returns an instance whose `execute` always returns an empty array. Use in unit tests.
    #if DEBUG
    public static let stub = FetchTagsUseCase(repository: StubMarketRepository())
    #endif
}
