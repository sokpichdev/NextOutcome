//
//  BracketBuilder.swift
//  NextOutcome
//
//  Created by Sok Pich on 04/07/2026.
//

import Foundation
import MarketsDomain

/// One nation's chance of advancing, from the "Nation To Reach …" futures market.
struct AdvanceRow: Identifiable, Equatable {
    let id: String
    let name: String
    let logoURL: URL?
    let percent: Double // 0…1
}

/// One side of a knockout match.
struct BracketTeam: Equatable {
    let name: String
    let abbreviation: String?
    let logoURL: URL?
    let colorHex: String?
    let score: Int?
    let winPercent: Double? // 0…1, nil once the game is final
    let isWinner: Bool
}

struct BracketMatch: Identifiable, Equatable {
    enum Status: Equatable { case scheduled, live, final }
    let id: String
    let title: String
    let kickoff: Date?
    let status: Status
    let home: BracketTeam?
    let away: BracketTeam?
}

/// A page of the bracket carousel.
enum BracketPage: Identifiable, Equatable {
    case groups([AdvanceRow])
    case matches(title: String, [BracketMatch])
    case placeholder(title: String)

    var id: String { title }

    var title: String {
        switch self {
        case .groups: return "Groups"
        case .matches(let title, _): return title
        case .placeholder(let title): return title
        }
    }
}

/// Assembles the bracket carousel from data the hub already loaded. The public sports feed
/// carries no round labels, venues, group tables, or future fixtures, so the live knockout
/// games form "Round of 16", the "Reach Quarterfinals" market backs the Groups advance board,
/// and later rounds are honest TBD placeholders until their fixtures are set.
enum BracketBuilder {
    static func pages(
        games: [Event],
        results: [String: GameResult],
        props: [Event],
        teams: [String: GameTeam] = [:]
    ) -> [BracketPage] {
        var pages: [BracketPage] = []

        let advance = advanceRows(
            from: props.first { $0.title.lowercased().contains("reach quarterfinals") },
            teams: teams
        )
        if !advance.isEmpty { pages.append(.groups(advance)) }

        let matches = games
            .compactMap { match(from: $0, result: results[$0.id], teams: teams) }
            .sorted { ($0.kickoff ?? .distantFuture) < ($1.kickoff ?? .distantFuture) }
        if !matches.isEmpty { pages.append(.matches(title: "Round of 16", matches)) }

        pages += [.placeholder(title: "Quarter-finals"),
                  .placeholder(title: "Semi-finals"),
                  .placeholder(title: "Final")]
        return pages
    }

    /// Top nations by advance chance, from the futures market's per-country outcomes, with
    /// flags filled from the team directory.
    static func advanceRows(from event: Event?, teams: [String: GameTeam] = [:], max: Int = 16) -> [AdvanceRow] {
        guard let event else { return [] }
        return event.markets
            .filter { $0.isActive && $0.yesOutcome != nil }
            .sorted { ($0.yesOutcome?.price ?? 0) > ($1.yesOutcome?.price ?? 0) }
            .prefix(max)
            .map { market in
                let name = market.groupItemTitle ?? market.question
                return AdvanceRow(
                    id: market.id,
                    name: name,
                    logoURL: market.imageURL ?? teams[name.lowercased()]?.logoURL,
                    percent: NSDecimalNumber(decimal: market.yesOutcome?.price ?? 0).doubleValue
                )
            }
    }

    /// Builds a match from a game's moneyline markets (team + win %) hydrated with the live
    /// result (logos, colours, score), falling back to the team directory. Returns nil if the
    /// game has no two teams.
    static func match(from game: Event, result: GameResult?, teams: [String: GameTeam] = [:]) -> BracketMatch? {
        let teamMarkets = WorldCupEventSplitter.moneylineMarkets(for: game)
            .filter { ($0.groupItemTitle?.lowercased().hasPrefix("draw") ?? false) == false }
        guard !teamMarkets.isEmpty else { return nil }

        let status: BracketMatch.Status = result?.live == true ? .live
            : (result?.ended == true ? .final : .scheduled)

        func side(index: Int, resultTeam: GameTeam?) -> BracketTeam? {
            let market = teamMarkets.indices.contains(index) ? teamMarkets[index] : nil
            let name = resultTeam?.name ?? market?.groupItemTitle
            guard let name else { return nil }
            let matched = resultTeam
                ?? result?.teams.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
                ?? teams[name.lowercased()]
            let score = index == 0 ? result?.homeScore : result?.awayScore
            let win = market?.yesOutcome.map { NSDecimalNumber(decimal: $0.price).doubleValue }
            return BracketTeam(
                name: name,
                abbreviation: matched?.abbreviation,
                logoURL: matched?.logoURL,
                colorHex: matched?.colorHex,
                score: status == .scheduled ? nil : score,
                winPercent: status == .final ? nil : win,
                isWinner: false
            )
        }

        var home = side(index: 0, resultTeam: result?.homeTeam)
        var away = side(index: 1, resultTeam: result?.awayTeam)

        // Mark the winner of a completed game by score.
        if status == .final, let h = home?.score, let a = away?.score {
            home = home.map { withWinner($0, isWinner: h > a) }
            away = away.map { withWinner($0, isWinner: a > h) }
        }

        return BracketMatch(id: game.id, title: game.title, kickoff: game.gameStartTime,
                            status: status, home: home, away: away)
    }

    private static func withWinner(_ team: BracketTeam, isWinner: Bool) -> BracketTeam {
        BracketTeam(name: team.name, abbreviation: team.abbreviation, logoURL: team.logoURL,
                    colorHex: team.colorHex, score: team.score, winPercent: team.winPercent,
                    isWinner: isWinner)
    }
}
