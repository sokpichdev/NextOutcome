//
//  FetchFeaturedEventsUseCase.swift
//  NextOutcome
//
//  Created by Sok Pich on 03/08/2026.
//

import SharedDomain

/// Loads Polymarket's curated featured list — the editorial ranking pinned above the feed.
public struct FetchFeaturedEventsUseCase: Sendable {
    /// The market repository backing this use case.
    private let repository: MarketRepository

    /// Creates the use case.
    /// - Parameter repository: The market repository to fetch from.
    public init(repository: MarketRepository) {
        self.repository = repository
    }

    /// Fetches the featured events, already in editorial rank order.
    ///
    /// Finished fixtures are dropped: a curated pin is a recommendation, and recommending a
    /// match that has already been played is the exact failure this whole change exists to
    /// fix. Ordinary markets are unaffected — they carry no `ended` flag.
    /// - Parameter limit: How many rows to request from Gamma.
    /// - Returns: The featured events, rank order preserved.
    public func execute(limit: Int = 12) async throws -> [Event] {
        try await repository.fetchFeaturedEvents(limit: limit).filter { !$0.isEnded }
    }

    /// Returns an instance whose `execute` always returns an empty list. Use in unit tests.
    #if DEBUG
    public static let stub = FetchFeaturedEventsUseCase(repository: StubMarketRepository())
    #endif
}
