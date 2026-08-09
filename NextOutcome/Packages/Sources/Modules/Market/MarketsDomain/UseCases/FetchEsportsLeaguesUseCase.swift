//
//  FetchEsportsLeaguesUseCase.swift
//  NextOutcome
//
//  Created by Sok Pich on 09/08/2026.
//

/// Fetches the game titles the Esports hub can show tiles for.
///
/// This replaced a three-case enum. The catalogue lives on the server, so the hub picks up a
/// new game the day Polymarket adds one — and the nine games the enum was missing (Valorant,
/// Honor of Kings, Mobile Legends, …) appear without a code change.
public struct FetchEsportsLeaguesUseCase: Sendable {
    /// The Gamma tag that scopes the catalogue to esports.
    public static let esportsTagID = "64"

    /// The market repository backing this use case.
    private let repository: MarketRepository

    /// Creates the use case.
    /// - Parameter repository: The market repository to fetch from.
    public init(repository: MarketRepository) {
        self.repository = repository
    }

    /// Returns the esports leagues, deduplicated, in catalogue order.
    ///
    /// The catalogue ships genuine duplicates — StarCraft: Brood War appears twice (slugs
    /// `sc` and `sc1`, different tag ids) under one shared series id. Collapsing on series id
    /// keeps one tile per game; entries without a series id are left alone, since nothing
    /// links them.
    public func execute() async throws -> [EsportsLeague] {
        var seenSeries: Set<String> = []
        return try await repository.fetchLeagues(tagID: Self.esportsTagID).filter { league in
            guard let series = league.seriesID else { return true }
            return seenSeries.insert(series).inserted
        }
    }
}
