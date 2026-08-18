//
//  FetchEsportsGamesUseCase.swift
//  NextOutcome
//
//  Created by Sok Pich on 17/08/2026.
//

import Foundation
import SharedDomain

/// Loads the Esports hub's matches, one page at a time.
///
/// This replaced a bulk read of the whole esports tag. That path walked five sequential pages
/// of 100 events — measured against the live API, 12.6 s and 33 MB before the hub could render
/// a single card, of which 90 events were season futures the hub discarded on arrival. Asking
/// the server for esports *matches*, 20 at a time, is what makes the hub open promptly.
public struct FetchEsportsGamesUseCase: Sendable {
    /// The market repository backing this use case.
    private let repository: MarketRepository

    /// Creates the use case.
    /// - Parameter repository: The market repository to fetch from.
    public init(repository: MarketRepository) {
        self.repository = repository
    }

    /// Fetches one page of matches.
    /// - Parameters:
    ///   - live: Ask for in-play matches only. These need their own request: the upcoming
    ///     query is bounded by kickoff, so a match already under way falls outside it.
    ///   - startingAfter: Lower bound on kickoff; also orders by kickoff ascending.
    ///   - cursor: Keyset cursor, `nil` for the first page.
    ///   - leagueTagID: Narrows to one game title; `nil` for every game.
    public func execute(
        live: Bool, startingAfter: Date?, cursor: String?, leagueTagID: String? = nil
    ) async throws -> Page<Event> {
        try await repository.fetchEsportsGames(
            live: live, startingAfter: startingAfter, cursor: cursor, leagueTagID: leagueTagID
        )
    }
}
