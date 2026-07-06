//
//  GameCard.swift
//  NextOutcome
//
//  Created by Sok Pich on 04/07/2026.
//

import SwiftUI
import MarketsDomain
import DesignSystem

/// Schedule card for one game: status/volume row, two team rows (score when live/final),
/// and the moneyline prices. Soccer moneylines are sibling binary markets — one per team
/// plus a draw, labelled via `groupItemTitle`, priced by their Yes side. Team names/logos
/// come from `/events/results` when available, falling back to the market labels.
struct GameCard: View {
    /// The game event.
    let event: Event
    /// The live/final result, if loaded.
    let result: GameResult?
    /// The game's moneyline markets (one per team plus a draw).
    let moneylines: [Market]
    /// Fired when a team's logo/name is tapped, with a lightweight profile target
    /// built from whichever team data is available (the loaded `GameResult`'s
    /// `GameTeam` when live scores are wired up, else the moneyline market's own
    /// name/image). `nil` (the default) leaves team rows non-interactive — tapping
    /// anywhere on the card still opens the event, same as today.
    let onTeamTap: ((TeamProfileTarget) -> Void)?
    /// The Gamma `/teams` league slug (e.g. "ufc", "mlb", "fifwc") used to enrich
    /// the tapped team's profile with its record. `nil` skips that lookup.
    let leagueSlug: String?
    /// The Sports hub's chosen odds display format (defaults to `.price` outside the hub).
    @Environment(\.oddsFormat) private var oddsFormat
    /// Whether to also show spread/total markets (Sports hub only).
    @Environment(\.showSpreadsAndTotals) private var showSpreadsAndTotals

    init(event: Event, result: GameResult? = nil, moneylines: [Market], onTeamTap: ((TeamProfileTarget) -> Void)? = nil, leagueSlug: String? = nil) {
        self.event = event
        self.result = result
        self.moneylines = moneylines
        self.onTeamTap = onTeamTap
        self.leagueSlug = leagueSlug
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DSLayout.spacing) {
            statusRow
            teamRow(side: .home)
            teamRow(side: .away)
            priceRow
            if showSpreadsAndTotals { spreadsAndTotalsSection }
        }
        .padding(DSLayout.margin)
        .background(DSColor.surface.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: DSLayout.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: DSLayout.cardRadius)
                .strokeBorder(DSColor.surfaceElevated, lineWidth: 1)
        )
    }

    // MARK: moneyline structure

    /// Whether a moneyline market is the "Draw" outcome.
    private func isDraw(_ market: Market) -> Bool {
        market.groupItemTitle?.lowercased().hasPrefix("draw") == true
    }

    /// The draw market, if present.
    private var drawMarket: Market? { moneylines.first(where: isDraw) }

    /// Team markets ordered home-first when results tell us the ordering.
    private var teamMarkets: [Market] {
        let teams = moneylines.filter { !isDraw($0) }
        guard let homeName = result?.homeTeam?.name,
              let homeIndex = teams.firstIndex(where: { $0.groupItemTitle?.caseInsensitiveCompare(homeName) == .orderedSame }),
              homeIndex != 0
        else { return teams }
        var reordered = teams
        reordered.swapAt(0, homeIndex)
        return reordered
    }

    // MARK: status

    /// The top row: live/final/kickoff status on the left, volume on the right.
    private var statusRow: some View {
        HStack(spacing: DSLayout.spacingSmall) {
            if result?.live == true {
                Circle().fill(DSColor.negative).frame(width: 6, height: 6)
                Text(liveStatusText)
                    .font(DSFont.caption.bold())
                    .foregroundStyle(DSColor.negative)
            } else if result?.ended == true {
                Text("Final")
                    .font(DSFont.caption.bold())
                    .foregroundStyle(DSColor.textSecondary)
            } else if let kickoff = event.gameStartTime {
                Text(kickoff, format: .dateTime.hour().minute())
                    .font(DSFont.caption.bold())
                    .foregroundStyle(DSColor.textSecondary)
            }
            Spacer()
            Text("\(MarketFormatting.compactUSD(event.volume)) Vol")
                .font(DSFont.caption)
                .foregroundStyle(DSColor.textSecondary)
        }
    }

    /// The live status text, combining period and elapsed time when available.
    private var liveStatusText: String {
        let period = result?.period ?? "Live"
        if let elapsed = result?.elapsed, !elapsed.isEmpty {
            return "\(period) · \(elapsed)"
        }
        return period
    }

    // MARK: teams

    /// Which side of the game a team row represents.
    private enum Side { case home, away }

    /// Builds a team row: optional score, then a tappable logo+name (when
    /// `onTeamTap` is set) for one side.
    /// - Parameter side: Home or away.
    private func teamRow(side: Side) -> some View {
        let index = side == .home ? 0 : 1
        let team = side == .home ? result?.homeTeam : result?.awayTeam
        let name = team?.name
            ?? (teamMarkets.indices.contains(index) ? teamMarkets[index].groupItemTitle : nil)
            ?? "TBD"
        let score = side == .home ? result?.homeScore : result?.awayScore

        return HStack(spacing: DSLayout.spacingMedium) {
            if let score, result?.live == true || result?.ended == true {
                Text("\(score)")
                    .font(DSFont.subheadline.bold())
                    .foregroundStyle(DSColor.textPrimary)
                    .frame(width: 28, height: 28)
                    .background(DSColor.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            teamTapArea(index: index, name: name, team: team)
            Spacer()
        }
    }

    /// The logo+name portion of a team row. Wrapped in a `Button` (instead of
    /// nesting a second `NavigationLink` inside the card's own outer one, which
    /// SwiftUI doesn't handle reliably) when `onTeamTap` is set.
    /// - Parameters:
    ///   - index: 0 for home, 1 for away — used to fall back to the moneyline
    ///     market's own name/image when no `GameResult` team loaded.
    ///   - name: The resolved display name.
    ///   - team: The `GameResult` team, if loaded.
    @ViewBuilder
    private func teamTapArea(index: Int, name: String, team: GameTeam?) -> some View {
        let logoURL = team?.logoURL ?? (teamMarkets.indices.contains(index) ? teamMarkets[index].imageURL : nil)
        let content = HStack(spacing: DSLayout.spacingMedium) {
            teamLogo(url: logoURL, name: name)
            Text(name)
                .font(DSFont.subheadline.bold())
                .foregroundStyle(DSColor.textPrimary)
                .lineLimit(1)
        }
        if let onTeamTap {
            Button {
                onTeamTap(TeamProfileTarget(name: name, logoURL: logoURL, colorHex: team?.colorHex, league: leagueSlug))
            } label: { content }
            .buttonStyle(.plain)
        } else {
            content
        }
    }

    /// The team logo, or a rounded placeholder showing the name's first letter.
    /// - Parameters:
    ///   - url: The logo URL, if any.
    ///   - name: The team name (for the placeholder initial).
    private func teamLogo(url: URL?, name: String) -> some View {
        AsyncImage(url: url) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            RoundedRectangle(cornerRadius: 6)
                .fill(DSColor.surfaceElevated)
                .overlay(
                    Text(name.prefix(1))
                        .font(DSFont.caption.bold())
                        .foregroundStyle(DSColor.textSecondary)
                )
        }
        .frame(width: 28, height: 20)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: prices

    /// The moneyline price buttons, ordered home · draw · away.
    private var priceRow: some View {
        let ordered: [Market?] = teamMarkets.count >= 2
            ? [teamMarkets[0], drawMarket, teamMarkets[1]]
            : teamMarkets + [drawMarket]

        return HStack(spacing: DSLayout.spacingSmall) {
            ForEach(ordered.compactMap { $0 }) { market in
                PriceButton(
                    title: shortLabel(for: market),
                    price: oddsFormat.format(market.yesOutcome?.price ?? 0),
                    style: style(for: market),
                    action: {}
                )
                .frame(maxWidth: .infinity) // equal thirds
            }
        }
    }

    // MARK: spreads & totals (Sports hub's "Show Spreads + Totals" toggle)

    /// One compact row per spread/total market: its sub-label plus a price button per
    /// outcome, formatted in the hub's chosen odds format.
    private var spreadsAndTotalsSection: some View {
        let groups = MarketGroupClassifier.groups(for: event.markets)
            .filter { $0.group == .spreads || $0.group == .totals }
        return Group {
            if !groups.isEmpty {
                Divider().overlay(DSColor.surfaceElevated)
                VStack(alignment: .leading, spacing: DSLayout.spacingSmall) {
                    ForEach(groups, id: \.group) { group in
                        ForEach(group.markets) { market in
                            spreadOrTotalRow(market)
                        }
                    }
                }
            }
        }
    }

    /// "Argentina -2.5" + a price button per outcome (Yes/No), in the hub's odds format.
    private func spreadOrTotalRow(_ market: Market) -> some View {
        HStack(spacing: DSLayout.spacingSmall) {
            Text(market.groupItemTitle ?? market.question)
                .font(DSFont.caption)
                .foregroundStyle(DSColor.textSecondary)
                .lineLimit(1)
            Spacer()
            ForEach(market.outcomes) { outcome in
                PriceButton(title: outcome.title, price: oddsFormat.format(outcome.price), style: .neutral, action: {})
            }
        }
    }

    /// Draw → neutral slot; each team → its brand colour filled (falling back to the
    /// app accent when the sports feed didn't send a colour).
    private func style(for market: Market) -> PriceButton.Style {
        if isDraw(market) { return .neutral }
        let color = team(for: market).flatMap { Color(hexString: $0.colorHex) } ?? DSColor.accent
        return .solid(color)
    }

    /// "COL 87¢"-style label: team abbreviation from results when the name matches,
    /// otherwise the first three letters of the market's team label. "DRAW" for the draw.
    private func shortLabel(for market: Market) -> String {
        if isDraw(market) { return "DRAW" }
        if let abbreviation = team(for: market)?.abbreviation { return abbreviation }
        return String((market.groupItemTitle ?? market.question).prefix(3)).uppercased()
    }

    /// Finds the result team matching a market's team label, if any.
    private func team(for market: Market) -> GameTeam? {
        let label = market.groupItemTitle ?? market.question
        return result?.teams.first { $0.name.caseInsensitiveCompare(label) == .orderedSame }
    }
}

#if DEBUG
#Preview("Scheduled · Live") {
    func moneyline(_ id: String, team: String, yes: Decimal) -> Market {
        Market(
            id: id, question: team, slug: id,
            outcomes: [Outcome(id: "\(id)-y", title: "Yes", price: yes),
                       Outcome(id: "\(id)-n", title: "No", price: 1 - yes)],
            volume: 0, liquidity: 0, endDate: nil, isResolved: false,
            imageURL: nil, sportsMarketType: "moneyline", groupItemTitle: team
        )
    }
    let markets = [
        moneyline("m1", team: "Colombia", yes: 0.87),
        moneyline("m2", team: "Draw (Colombia vs. Ghana)", yes: 0.12),
        moneyline("m3", team: "Ghana", yes: 0.025),
    ]
    let event = Event(
        id: "e1", title: "Colombia vs. Ghana", slug: "col-gha", markets: markets,
        volume: 23_430_000, imageURL: nil, gameStartTime: .now.addingTimeInterval(7200)
    )
    let live = GameResult(
        eventID: "e1", score: "1-0", elapsed: "66", period: "2H", live: true, ended: false,
        teams: [
            GameTeam(name: "Colombia", abbreviation: "COL", logoURL: nil, colorHex: nil, ordering: "home"),
            GameTeam(name: "Ghana", abbreviation: "GHA", logoURL: nil, colorHex: nil, ordering: "away"),
        ]
    )
    return VStack(spacing: 12) {
        GameCard(event: event, result: nil, moneylines: markets)
        GameCard(event: event, result: live, moneylines: markets)
    }
    .padding()
    .background(DSColor.background)
}
#endif
