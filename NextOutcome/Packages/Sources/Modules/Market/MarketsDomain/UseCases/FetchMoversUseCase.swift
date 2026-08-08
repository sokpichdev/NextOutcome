//
//  FetchMoversUseCase.swift
//  NextOutcome
//
//  Created by Sok Pich on 05/07/2026.
//

/// Loads the ranked list of biggest 24h market movers for the Breaking feed, optionally
/// scoped to a category tag.
public struct FetchMoversUseCase: Sendable {
    /// The market repository backing this use case.
    private let repository: MarketRepository

    /// Creates the use case.
    /// - Parameter repository: The market repository to fetch from.
    public init(repository: MarketRepository) {
        self.repository = repository
    }

    /// Fetches the top movers, ranked by the magnitude of their 24h probability move.
    /// - Parameter tagID: An optional category tag to scope the movers to (`nil` = all).
    /// - Returns: The ranked movers, biggest move first.
    public func execute(tagID: String?) async throws -> [Mover] {
        try await repository.movers(tagID: tagID)
    }

    /// Returns an instance whose `execute` always throws. Use in unit tests.
    #if DEBUG
    public static let stub = FetchMoversUseCase(repository: StubMarketRepository())
    #endif
}
