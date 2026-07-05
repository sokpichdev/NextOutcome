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
    /// Stable identity (the source market id).
    let id: String
    /// The nation's name.
    let name: String
    /// The nation's flag/logo, if known.
    let logoURL: URL?
    /// The chance to advance, 0…1.
    let percent: Double // 0…1
}

/// A team within a group card.
struct GroupTeam: Identifiable, Equatable {
    /// Stable identity.
    let id: String
    /// The team's name.
    let name: String
    /// The team's flag/logo, if known.
    let logoURL: URL?
    /// The team's brand colour hex, if known.
    let colorHex: String?
    /// Chance to reach the quarter-finals (0…1), or `nil` if unknown.
    let advancePercent: Double? // chance to reach the quarter-finals, nil if unknown
    /// Whether the team has been eliminated.
    let isOut: Bool
}

/// A group's teams (e.g. "Group A"), from the per-group winner market.
struct GroupStanding: Identifiable, Equatable {
    /// The group letter (e.g. "A").
    let id: String   // "A"
    /// The group's display name (e.g. "Group A").
    let name: String // "Group A"
    /// The teams in the group, ranked by advance chance.
    let teams: [GroupTeam]
}

/// The Groups page: real group cards when available, else the flat advance board.
struct GroupsData: Equatable {
    /// The per-group standings (may be empty).
    let standings: [GroupStanding]
    /// The flat advance board fallback (may be empty).
    let advance: [AdvanceRow]
}

/// One side of a knockout match.
struct BracketTeam: Equatable {
    /// The team's name.
    let name: String
    /// The team's abbreviation, if known.
    let abbreviation: String?
    /// The team's flag/logo, if known.
    let logoURL: URL?
    /// The team's brand colour hex, if known.
    let colorHex: String?
    /// The team's score, or `nil` before the game starts.
    let score: Int?
    /// Win probability (0…1), or `nil` once the game is final.
    let winPercent: Double? // 0…1, nil once the game is final
    /// Whether this team won a completed match.
    let isWinner: Bool
}

/// One knockout match (two sides, plus status).
struct BracketMatch: Identifiable, Equatable {
    /// The match lifecycle status.
    enum Status: Equatable { case scheduled, live, final }
    /// Stable identity (the source event id).
    let id: String
    /// The match title.
    let title: String
    /// Kickoff time, if known.
    let kickoff: Date?
    /// Whether the match is scheduled, live, or final.
    let status: Status
    /// The home side, if known.
    let home: BracketTeam?
    /// The away side, if known.
    let away: BracketTeam?
}

/// A page of the bracket carousel.
enum BracketPage: Identifiable, Equatable {
    /// The group-stage page.
    case groups(GroupsData)
    /// A round of matches, with a round title.
    case matches(title: String, [BracketMatch])
    /// A TBD placeholder round (fixtures not yet set).
    case placeholder(title: String)

    /// The page's identity (its title).
    var id: String { title }

    /// The page's display title.
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
    /// Assembles the ordered pages of the bracket carousel from the hub's already-loaded
    /// data: a Groups page (group cards or advance board), the completed "Round of 32", the
    /// live "Round of 16", and honest TBD placeholders for later rounds.
    /// - Parameters:
    ///   - games: The current-round games.
    ///   - completedGames: Previously-finished games.
    ///   - results: Live/final results keyed by event id.
    ///   - props: Prop/futures events (used for the advance market).
    ///   - groupEvents: Per-group winner events.
    ///   - teams: Team directory for flags/colours.
    /// - Returns: The ordered bracket pages.
    static func pages(
        games: [Event],
        completedGames: [Event] = [],
        results: [String: GameResult],
        props: [Event],
        groupEvents: [Event] = [],
        teams: [String: GameTeam] = [:]
    ) -> [BracketPage] {
        var pages: [BracketPage] = []

        let advanceEvent = props.first { $0.title.lowercased().contains("reach quarterfinals") }
        let advance = advanceRows(from: advanceEvent, teams: teams)
        let standings = groupStandings(groupEvents: groupEvents, advanceEvent: advanceEvent, teams: teams)
        if !advance.isEmpty || !standings.isEmpty {
            pages.append(.groups(GroupsData(standings: standings, advance: advance)))
        }

        let previous = completedGames
            .compactMap { match(from: $0, result: results[$0.id], teams: teams) }
            .sorted { ($0.kickoff ?? .distantPast) > ($1.kickoff ?? .distantPast) }
        if !previous.isEmpty { pages.append(.matches(title: "Round of 32", previous)) }

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
    /// - Parameters:
    ///   - event: The "Nation To Reach …" futures event, if present.
    ///   - teams: Team directory for flags.
    ///   - max: The maximum number of rows to return.
    /// - Returns: The top nations by advance chance.
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

    /// Group cards from the per-group winner markets (which list each group's teams), with
    /// each team's chance to reach the quarter-finals pulled from the advance market.
    /// - Parameters:
    ///   - groupEvents: The per-group winner events.
    ///   - advanceEvent: The advance ("Reach Quarterfinals") event, for each team's chance.
    ///   - teams: Team directory for flags/colours.
    /// - Returns: The group standings, sorted by group letter.
    static func groupStandings(
        groupEvents: [Event],
        advanceEvent: Event?,
        teams: [String: GameTeam] = [:]
    ) -> [GroupStanding] {
        let advance = advanceInfo(from: advanceEvent)

        return groupEvents.compactMap { event -> GroupStanding? in
            guard let letter = groupLetter(from: event) else { return nil }
            let members = event.markets
                .compactMap { $0.groupItemTitle ?? ($0.question.isEmpty ? nil : $0.question) }
                .filter { !["other", "field"].contains($0.lowercased()) }

            let groupTeams = members.enumerated().map { index, name -> GroupTeam in
                let info = advance[name.lowercased()]
                let team = teams[name.lowercased()]
                return GroupTeam(
                    id: "\(event.id)-\(index)",
                    name: name,
                    logoURL: team?.logoURL,
                    colorHex: team?.colorHex,
                    advancePercent: info?.percent,
                    isOut: info?.isOut ?? false
                )
            }
            .sorted { ($0.advancePercent ?? -1) > ($1.advancePercent ?? -1) }

            guard !groupTeams.isEmpty else { return nil }
            return GroupStanding(id: letter, name: "Group \(letter)", teams: groupTeams)
        }
        .sorted { $0.id < $1.id }
    }

    /// name → (advance %, eliminated) from the "Reach Quarterfinals" market.
    /// - Parameter event: The advance market event.
    /// - Returns: A map of lowercased team name → (advance %, whether eliminated).
    private static func advanceInfo(from event: Event?) -> [String: (percent: Double, isOut: Bool)] {
        guard let event else { return [:] }
        var map: [String: (Double, Bool)] = [:]
        for market in event.markets where market.yesOutcome != nil {
            let name = (market.groupItemTitle ?? market.question).lowercased()
            let price = NSDecimalNumber(decimal: market.yesOutcome?.price ?? 0).doubleValue
            map[name] = (price, market.isResolved && price < 0.5)
        }
        return map
    }

    /// "World Cup Group C Winner" / slug "world-cup-group-c-winner" → "C".
    /// Extracts the group letter from an event's slug or title.
    /// - Parameter event: The group event.
    /// - Returns: The single-letter group id (e.g. "C"), or `nil` if not found.
    private static func groupLetter(from event: Event) -> String? {
        if let range = event.slug.range(of: "group-"),
           let end = event.slug[range.upperBound...].firstIndex(of: "-") {
            let letter = event.slug[range.upperBound..<end]
            if letter.count == 1 { return letter.uppercased() }
        }
        let words = event.title.split(separator: " ")
        if let i = words.firstIndex(where: { $0.lowercased() == "group" }), i + 1 < words.count {
            let candidate = words[i + 1]
            if candidate.count == 1 { return candidate.uppercased() }
        }
        return nil
    }

    /// Builds a match from a game's moneyline markets (team + win %) hydrated with the live
    /// result (logos, colours, score), falling back to the team directory. Returns nil if the
    /// game has no two teams.
    /// - Parameters:
    ///   - game: The game event.
    ///   - result: The live/final result, if any.
    ///   - teams: Team directory fallback for logos/colours.
    /// - Returns: A `BracketMatch`, or `nil` if the game has no two teams.
    static func match(from game: Event, result: GameResult?, teams: [String: GameTeam] = [:]) -> BracketMatch? {
        let teamMarkets = WorldCupEventSplitter.moneylineMarkets(for: game)
            .filter { ($0.groupItemTitle?.lowercased().hasPrefix("draw") ?? false) == false }
        guard !teamMarkets.isEmpty else { return nil }

        // A resolved game is final even before its score has been fetched.
        let status: BracketMatch.Status = result?.live == true ? .live
            : (result?.ended == true || game.isResolved ? .final : .scheduled)

        // Builds one side (home/away) from its moneyline market, hydrated with result data.
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

        // Mark the winner of a completed game — by score when available, otherwise by which
        // team's moneyline resolved higher (Yes ≈ 1 for the team that went through).
        if status == .final {
            let homeWon: Bool
            if let h = home?.score, let a = away?.score {
                homeWon = h > a
            } else {
                let hy = teamMarkets.first?.yesOutcome?.price ?? 0
                let ay = teamMarkets.dropFirst().first?.yesOutcome?.price ?? 0
                homeWon = hy >= ay
            }
            home = home.map { withWinner($0, isWinner: homeWon) }
            away = away.map { withWinner($0, isWinner: !homeWon) }
        }

        return BracketMatch(id: game.id, title: game.title, kickoff: game.gameStartTime,
                            status: status, home: home, away: away)
    }

    /// Returns a copy of `team` with its `isWinner` flag set.
    private static func withWinner(_ team: BracketTeam, isWinner: Bool) -> BracketTeam {
        BracketTeam(name: team.name, abbreviation: team.abbreviation, logoURL: team.logoURL,
                    colorHex: team.colorHex, score: team.score, winPercent: team.winPercent,
                    isWinner: isWinner)
    }
}
