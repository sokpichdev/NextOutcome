//
//  EsportsMatchInfo.swift
//  NextOutcome
//
//  Created by Sok Pich on 14/07/2026.
//

import Foundation
import MarketsDomain

/// A display-ready read of one esports match, shared by the hero card and the list card:
/// the two teams (name, logo, colour, price, series score) resolved from the event's
/// series moneyline market, its parsed title, and the `/events/results` payload.
struct EsportsMatchInfo {
    /// One side of the match with everything its row renders.
    struct Team {
        /// The team's display name.
        let name: String
        /// The team's logo, when `/events/results` provided one.
        let logoURL: URL?
        /// The team's brand colour hex, when provided.
        let colorHex: String?
        /// The team's current win probability (0…1), from the moneyline outcome.
        let price: Decimal?
        /// The team's series score (maps won), when the match is live/finished.
        let seriesScore: Int?
    }

    /// The home-side team (first in the title).
    let home: Team
    /// The away-side team (second in the title).
    let away: Team
    /// The parsed title parts (series format, tournament).
    let title: EsportsCatalog.MatchTitle?
    /// The featured game this match belongs to, if recognised.
    let game: EsportsGame?
    /// The series moneyline market backing the prices, if found.
    let moneyline: Market?

    /// Builds the display info from the raw event + optional live result.
    init(event: Event, result: GameResult?) {
        let title = EsportsCatalog.matchTitle(from: event.title)
        self.title = title
        self.game = EsportsCatalog.game(for: event)

        // The series-level moneyline: a two-outcome market whose outcomes are the teams.
        // Prefer the plain "moneyline" over per-map "child_moneyline" markets.
        let candidates = event.markets.filter { $0.outcomes.count == 2 && $0.isActive }
        let moneyline = candidates.first { $0.sportsMarketType?.lowercased() == "moneyline" }
            ?? candidates.first { $0.sportsMarketType?.lowercased().contains("moneyline") == true }
            ?? candidates.first
        self.moneyline = moneyline

        let score = EsportsHubViewModel.seriesScore(from: result?.score)
        let homeName = result?.homeTeam?.name ?? title?.homeTeam ?? moneyline?.outcomes.first?.title ?? "TBD"
        let awayName = result?.awayTeam?.name ?? title?.awayTeam ?? moneyline?.outcomes.last?.title ?? "TBD"

        /// The outcome whose title best matches a team name (exact, then prefix/contains).
        func outcome(for name: String, fallbackIndex: Int) -> Outcome? {
            guard let outcomes = moneyline?.outcomes else { return nil }
            if let exact = outcomes.first(where: { $0.title.caseInsensitiveCompare(name) == .orderedSame }) {
                return exact
            }
            if let partial = outcomes.first(where: {
                name.localizedCaseInsensitiveContains($0.title) || $0.title.localizedCaseInsensitiveContains(name)
            }) {
                return partial
            }
            return outcomes.indices.contains(fallbackIndex) ? outcomes[fallbackIndex] : nil
        }

        home = Team(
            name: homeName,
            logoURL: result?.homeTeam?.logoURL,
            colorHex: result?.homeTeam?.colorHex,
            price: outcome(for: homeName, fallbackIndex: 0)?.price,
            seriesScore: score?.home
        )
        away = Team(
            name: awayName,
            logoURL: result?.awayTeam?.logoURL,
            colorHex: result?.awayTeam?.colorHex,
            price: outcome(for: awayName, fallbackIndex: 1)?.price,
            seriesScore: score?.away
        )
    }
}
