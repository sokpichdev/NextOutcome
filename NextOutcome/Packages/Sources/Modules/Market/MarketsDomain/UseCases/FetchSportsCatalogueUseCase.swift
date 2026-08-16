//
//  FetchSportsCatalogueUseCase.swift
//  NextOutcome
//
//  Created by Sok Pich on 16/08/2026.
//

import Foundation

/// Builds the Sports hub's taxonomy: every league Polymarket runs markets for, bucketed into
/// sports and ranked by how much they trade.
///
/// This replaced a hardcoded list of five keyword-matched chips. The catalogue lives on the
/// server, so the hub gains a sport the day Polymarket adds one, shows real counts, and stops
/// losing Wimbledon for fifty weeks of the year.
public struct FetchSportsCatalogueUseCase: Sendable {
    /// The Gamma tag scoping the esports catalogue, excluded here — it has its own hub.
    static let esportsTagID = "64"

    /// The market repository backing this use case.
    private let repository: MarketRepository

    /// Creates the use case.
    /// - Parameter repository: The market repository to fetch from.
    public init(repository: MarketRepository) {
        self.repository = repository
    }

    /// Returns the sports taxonomy, highest volume first.
    ///
    /// Leagues that belong to no known sport each become a single-league group of their own.
    /// That is not a failure mode: MLB carries its own tag rather than baseball's, so it
    /// surfaces as a top-level "MLB 118" row above a separate Baseball group — exactly how
    /// the reference renders it.
    public func execute() async throws -> [SportGroup] {
        let leagues = try await repository.fetchSportsCatalogue()
            .filter { $0.groupTagID != Self.esportsTagID }

        var buckets: [String: [SportLeague]] = [:]
        var order: [String] = []
        for league in leagues {
            let key = league.groupTagID ?? league.id
            if buckets[key] == nil { order.append(key) }
            buckets[key, default: []].append(league)
        }

        return order.map { key -> SportGroup in
            let members = (buckets[key] ?? []).sorted { $0.volume > $1.volume }
            // A leaf takes its league's own name and key art; a real group takes the
            // table's, since no single league can speak for "Soccer".
            let presentation = members.count == 1 && members[0].groupTagID == nil
                ? (name: members[0].name, glyph: SportGroupCatalog.fallbackGlyph)
                : SportGroupCatalog.presentation(forGroupTagID: key)
            return SportGroup(id: key, name: presentation.name, glyph: presentation.glyph, leagues: members)
        }
        .sorted { $0.volume > $1.volume }
    }
}
