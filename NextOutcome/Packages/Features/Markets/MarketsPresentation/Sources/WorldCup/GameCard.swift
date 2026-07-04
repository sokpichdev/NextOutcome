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
    let event: Event
    let result: GameResult?
    let moneylines: [Market]

    var body: some View {
        VStack(alignment: .leading, spacing: DSLayout.spacing) {
            statusRow
            teamRow(side: .home)
            teamRow(side: .away)
            priceRow
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

    private func isDraw(_ market: Market) -> Bool {
        market.groupItemTitle?.lowercased().hasPrefix("draw") == true
    }

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

    private var liveStatusText: String {
        let period = result?.period ?? "Live"
        if let elapsed = result?.elapsed, !elapsed.isEmpty {
            return "\(period) · \(elapsed)"
        }
        return period
    }

    // MARK: teams

    private enum Side { case home, away }

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
            teamLogo(url: team?.logoURL, name: name)
            Text(name)
                .font(DSFont.subheadline.bold())
                .foregroundStyle(DSColor.textPrimary)
                .lineLimit(1)
            Spacer()
        }
    }

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

    private var priceRow: some View {
        let ordered: [Market?] = teamMarkets.count >= 2
            ? [teamMarkets[0], drawMarket, teamMarkets[1]]
            : teamMarkets + [drawMarket]

        return HStack(spacing: DSLayout.spacingSmall) {
            ForEach(ordered.compactMap { $0 }) { market in
                PriceButton(
                    title: shortLabel(for: market),
                    price: MarketFormatting.cents(market.yesOutcome?.price ?? 0),
                    style: .team,
                    action: {}
                )
                .frame(maxWidth: .infinity) // equal thirds so no button wraps its price
            }
        }
    }

    /// "COL 87¢"-style label: team abbreviation from results when the name matches,
    /// otherwise the first three letters of the market's team label.
    private func shortLabel(for market: Market) -> String {
        if isDraw(market) { return "Draw" }
        let label = market.groupItemTitle ?? market.question
        if let team = result?.teams.first(where: { $0.name.caseInsensitiveCompare(label) == .orderedSame }),
           let abbreviation = team.abbreviation {
            return abbreviation
        }
        return String(label.prefix(3)).uppercased()
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
