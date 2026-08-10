//
//  EsportsScoreboard.swift
//  NextOutcome
//
//  Created by Sok Pich on 10/08/2026.
//

import SwiftUI
import MarketsDomain
import DesignSystem

/// Builds the match detail screen's scoreboard: both teams, one column per map, and the
/// series score.
///
/// A note on what this can and can't show. Web's match page prints a round score per map
/// ("M1 16–14"), but no Polymarket API exposes one: the feed's score string carries only the
/// score of the map *being played* (see `EsportsSeriesScore`), and once a map ends that
/// number is gone. So finished maps are marked with their **winner**, taken from the
/// "Map N Winner" markets, and only the map in progress shows a live score. Inventing a
/// round score for a finished map would be the one thing worse than omitting it.
enum EsportsScoreboardBuilder {

    /// Which side of the match a value belongs to.
    enum Side: Equatable { case home, away }

    /// The state of one map in the series.
    enum MapState: Equatable {
        /// The map finished and this side won it.
        case won(Side)
        /// The map is being played, with the live score so far.
        case inProgress(home: Int, away: Int)
        /// The map hasn't been played yet.
        case unplayed
        /// The map will never be played — the series was already decided.
        case void
    }

    /// One map column.
    struct MapColumn: Equatable, Identifiable {
        /// The map number, 1-based. Doubles as the column's identity.
        let number: Int
        /// What to render in the column.
        let state: MapState
        /// `Identifiable` conformance.
        var id: Int { number }
    }

    /// One side's row.
    struct TeamRow: Equatable {
        /// The team's display name.
        let name: String
        /// The team's logo, when the result supplied one.
        let logoURL: URL?
        /// The team's brand colour hex, when supplied.
        let colorHex: String?
        /// Maps won so far, when the series score is known.
        let mapsWon: Int?
    }

    /// Everything `EsportsScoreboardView` renders.
    struct Model: Equatable {
        /// The home side's row.
        let home: TeamRow
        /// The away side's row.
        let away: TeamRow
        /// One column per map in the series.
        let columns: [MapColumn]
        /// The series summary line ("1 – 1 · Bo3"), or `nil` when no score has arrived.
        let seriesLine: String?
    }

    /// Builds the scoreboard from an event and its latest result.
    /// - Parameters:
    ///   - event: The match event, for its "Map N Winner" markets and title fallback.
    ///   - result: The latest live/final result, when one has loaded.
    ///   - league: The match's game, unused for layout but kept for caller symmetry.
    /// - Returns: The rendered model.
    static func build(event: Event, result: GameResult?, league: EsportsLeague? = nil) -> Model {
        let info = EsportsMatchInfo(event: event, result: result, league: league)
        let score = EsportsSeriesScore.parse(result?.score)
        let progress = EsportsMatchProgress.parse(result?.period)

        let home = TeamRow(name: info.home.name, logoURL: info.home.logoURL,
                           colorHex: info.home.colorHex, mapsWon: score?.seriesScore?.home)
        let away = TeamRow(name: info.away.name, logoURL: info.away.logoURL,
                           colorHex: info.away.colorHex, mapsWon: score?.seriesScore?.away)

        let mapMarkets = mapWinnerMarkets(in: event)
        let total = mapCount(progress: progress, score: score, mapMarkets: mapMarkets)
        let decided = isSeriesDecided(score: score, bestOf: score?.bestOf ?? total)

        let columns = (1...total).map { number in
            MapColumn(
                number: number,
                state: state(
                    forMap: number, market: mapMarkets[number], result: result,
                    currentMap: progress?.currentMap, mapScore: score?.mapScore,
                    seriesDecided: decided
                )
            )
        }

        return Model(home: home, away: away, columns: columns,
                     seriesLine: seriesLine(score: score))
    }

    // MARK: - Pieces

    /// The "Map N Winner" markets, keyed by map number.
    private static func mapWinnerMarkets(in event: Event) -> [Int: Market] {
        var byMap: [Int: Market] = [:]
        for market in event.markets where market.sportsMarketType?.lowercased() == "child_moneyline" {
            guard let number = MarketGroupClassifier.mapNumber(for: market) else { continue }
            byMap[number] = market
        }
        return byMap
    }

    /// How many columns to draw, preferring the most authoritative source available. Always
    /// at least one, so a match with no data at all still renders a row rather than crashing
    /// on an empty range.
    private static func mapCount(
        progress: EsportsMatchProgress?, score: EsportsSeriesScore?, mapMarkets: [Int: Market]
    ) -> Int {
        max(progress?.totalMaps ?? score?.bestOf ?? mapMarkets.keys.max() ?? 1, 1)
    }

    /// Whether one side has already taken the series, so the remaining maps won't be played.
    private static func isSeriesDecided(score: EsportsSeriesScore?, bestOf: Int) -> Bool {
        guard let series = score?.seriesScore, bestOf >= 1 else { return false }
        return max(series.home, series.away) > bestOf / 2
    }

    /// The state of a single map column.
    private static func state(
        forMap number: Int, market: Market?, result: GameResult?,
        currentMap: Int?, mapScore: EsportsScorePair?, seriesDecided: Bool
    ) -> MapState {
        if let market, let winner = settledWinner(of: market, result: result) {
            return .won(winner)
        }
        if number == currentMap, result?.ended != true {
            guard let mapScore else { return .unplayed }
            return .inProgress(home: mapScore.home, away: mapScore.away)
        }
        // Gamma leaves "Map 3 Winner" open at 0.5/0.5 after a 2-0 Bo3. Showing that as
        // upcoming would promise a map that will never happen.
        return seriesDecided ? .void : .unplayed
    }

    /// The side that won a settled map, or `nil` while it's still in play.
    ///
    /// Reads the price as well as `isResolved`: Gamma had "Map 1 Winner" sitting at
    /// 0.9995/0.0005 while the event was still open, so waiting for the resolved flag would
    /// leave a decided map reading as unplayed for the rest of the series.
    private static func settledWinner(of market: Market, result: GameResult?) -> Side? {
        guard let top = market.outcomes.max(by: { $0.price < $1.price }) else { return nil }
        guard market.isResolved || top.price >= 0.99 else { return nil }
        return side(named: top.title, in: market, result: result)
    }

    /// Which side an outcome title names — exact match, then containment, then the outcome's
    /// position in the market. The same ladder `EsportsMatchInfo` uses to pair prices to teams.
    private static func side(named title: String, in market: Market, result: GameResult?) -> Side? {
        if let home = result?.homeTeam?.name, matches(title, home) { return .home }
        if let away = result?.awayTeam?.name, matches(title, away) { return .away }
        guard let index = market.outcomes.firstIndex(where: { $0.title == title }) else { return nil }
        return index == 0 ? .home : .away
    }

    /// Whether an outcome title and a team name refer to the same team.
    private static func matches(_ title: String, _ teamName: String) -> Bool {
        if title.caseInsensitiveCompare(teamName) == .orderedSame { return true }
        guard !title.isEmpty, !teamName.isEmpty else { return false }
        return title.localizedCaseInsensitiveContains(teamName)
            || teamName.localizedCaseInsensitiveContains(title)
    }

    /// "1 – 1 · Bo3", or `nil` when no series score has arrived.
    private static func seriesLine(score: EsportsSeriesScore?) -> String? {
        guard let series = score?.seriesScore else { return nil }
        let line = "\(series.home) – \(series.away)"
        guard let format = score?.format else { return line }
        return "\(line) · \(format)"
    }
}

/// The match detail screen's scoreboard: a row per team with one cell per map, mirroring
/// web's M1/M2/M3 grid.
struct EsportsScoreboardView: View {
    /// The model to render.
    let model: EsportsScoreboardBuilder.Model

    var body: some View {
        DSCard {
            VStack(alignment: .leading, spacing: DSLayout.spacing) {
                header
                teamRow(model.home, side: .home)
                Divider().overlay(DSColor.separator)
                teamRow(model.away, side: .away)
                if let seriesLine = model.seriesLine {
                    Text(seriesLine)
                        .font(DSFont.caption)
                        .foregroundStyle(DSColor.textSecondary)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("esports.scoreboard")
    }

    /// The "M1 M2 M3" column headings, indented past the team-name column.
    private var header: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            ForEach(model.columns) { column in
                Text("M\(column.number)")
                    .font(DSFont.caption2.bold())
                    .foregroundStyle(DSColor.textSecondary)
                    .frame(width: Self.columnWidth)
            }
        }
    }

    /// One team's row: logo, name, then its cell in every map column.
    private func teamRow(_ team: EsportsScoreboardBuilder.TeamRow,
                         side: EsportsScoreboardBuilder.Side) -> some View {
        HStack(spacing: 0) {
            EsportsTeamLogo(url: team.logoURL, name: team.name, size: 26)
            Text(team.name)
                .font(DSFont.subheadline.bold())
                .foregroundStyle(DSColor.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.leading, DSLayout.spacingMedium)
            Spacer(minLength: DSLayout.spacingSmall)
            ForEach(model.columns) { column in
                cell(column.state, for: side, teamColorHex: team.colorHex)
                    .frame(width: Self.columnWidth)
            }
        }
    }

    /// One map cell for one side.
    @ViewBuilder
    private func cell(_ state: EsportsScoreboardBuilder.MapState,
                      for side: EsportsScoreboardBuilder.Side,
                      teamColorHex: String?) -> some View {
        switch state {
        case .won(let winner) where winner == side:
            Image(systemName: "checkmark")
                .font(DSFont.caption.bold())
                .foregroundStyle(Color(hexString: teamColorHex) ?? DSColor.positive)
        case .won:
            Text("·")
                .font(DSFont.subheadline)
                .foregroundStyle(DSColor.textSecondary)
        case .inProgress(let home, let away):
            Text("\(side == .home ? home : away)")
                .font(DSFont.subheadline.bold())
                .foregroundStyle(DSColor.textPrimary)
        case .unplayed, .void:
            Text("–")
                .font(DSFont.subheadline)
                .foregroundStyle(DSColor.textSecondary)
        }
    }

    /// Width of one map column. Five of these still fit a compact width alongside a
    /// scaled-down team name, which covers Bo5.
    private static let columnWidth: CGFloat = 30
}

#if DEBUG
#Preview("Scoreboard — live Bo3, one map each") {
    let markets = [
        Market(id: "m1", question: "Map 1 Winner", slug: "m1",
               outcomes: [Outcome(id: "a", title: "Eternal Fire Academy", price: 0.9995),
                          Outcome(id: "b", title: "Vitality Academy", price: 0.0005)],
               volume: 0, liquidity: 0, endDate: nil, isResolved: false, imageURL: nil,
               sportsMarketType: "child_moneyline", groupItemTitle: "Map 1 Winner"),
        Market(id: "m2", question: "Map 2 Winner", slug: "m2",
               outcomes: [Outcome(id: "a", title: "Eternal Fire Academy", price: 0.0005),
                          Outcome(id: "b", title: "Vitality Academy", price: 0.9995)],
               volume: 0, liquidity: 0, endDate: nil, isResolved: false, imageURL: nil,
               sportsMarketType: "child_moneyline", groupItemTitle: "Map 2 Winner"),
    ]
    let event = Event(id: "e", title: "Counter-Strike: Eternal Fire Academy vs Vitality Academy (BO3)",
                      slug: "e", markets: markets, volume: 88_270, imageURL: nil)
    let result = GameResult(
        eventID: "e", score: "7-5|1-1|Bo3", elapsed: nil, period: "3/3", live: true, ended: false,
        teams: [GameTeam(name: "Eternal Fire Academy", abbreviation: "EFA", logoURL: nil,
                         colorHex: "#29447c", ordering: "home"),
                GameTeam(name: "Vitality Academy", abbreviation: "VITA", logoURL: nil,
                         colorHex: "#ffff00", ordering: "away")]
    )
    return EsportsScoreboardView(model: EsportsScoreboardBuilder.build(event: event, result: result))
        .padding()
        .background(DSColor.background)
}
#endif
