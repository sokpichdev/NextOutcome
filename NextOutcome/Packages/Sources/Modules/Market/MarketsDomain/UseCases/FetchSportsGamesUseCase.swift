//
//  FetchSportsGamesUseCase.swift
//  NextOutcome
//
//  Created by Sok Pich on 16/08/2026.
//

import Foundation
import SharedDomain

/// Loads the Sports hub's games — real fixtures only, esports excluded.
///
/// The hub used to read the general sports tag ranked by 24h volume, a feed dominated by
/// season futures: 20 fetched events yielded 4 games and none in play. Asking for games
/// directly is what makes the feed about games.
public struct FetchSportsGamesUseCase: Sendable {
    /// The market repository backing this use case.
    private let repository: MarketRepository

    /// Creates the use case.
    /// - Parameter repository: The market repository to fetch from.
    public init(repository: MarketRepository) {
        self.repository = repository
    }

    /// Fetches one page of games.
    /// - Parameters:
    ///   - live: Ask for in-play games only. These need their own request: the upcoming query
    ///     is bounded by kickoff, so a game already under way falls outside it.
    ///   - startingAfter: Lower bound on kickoff; also orders by kickoff ascending.
    ///   - cursor: Keyset cursor, `nil` for the first page.
    ///   - leagueTagID: Narrows to one sport or league; `nil` for the whole feed.
    public func execute(
        live: Bool, startingAfter: Date?, cursor: String?, leagueTagID: String? = nil
    ) async throws -> Page<Event> {
        try await repository.fetchSportsGames(
            live: live, startingAfter: startingAfter, cursor: cursor, leagueTagID: leagueTagID
        )
    }
}
