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
/// and the moneyline prices. Team names/logos come from `/events/results` when available,
/// falling back to the moneyline outcome titles before scores load.
struct GameCard: View {
    let event: Event
    let result: GameResult?
    let moneyline: Market?

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
        let team = side == .home ? result?.homeTeam : result?.awayTeam
        let name = team?.name ?? fallbackTeamNames[side == .home ? 0 : 1, default: "TBD"]
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

    /// Moneyline outcome titles minus "Draw" — the pre-results stand-in for team names.
    private var fallbackTeamNames: [Int: String] {
        let names = (moneyline?.outcomes ?? [])
            .map(\.title)
            .filter { $0.caseInsensitiveCompare("Draw") != .orderedSame }
        return Dictionary(uniqueKeysWithValues: names.prefix(2).enumerated().map { ($0, $1) })
    }

    // MARK: prices

    private var priceRow: some View {
        HStack(spacing: DSLayout.spacingSmall) {
            ForEach((moneyline?.outcomes ?? []).prefix(3)) { outcome in
                PriceButton(
                    title: shortLabel(for: outcome.title),
                    price: MarketFormatting.cents(outcome.price),
                    style: .team,
                    action: {}
                )
            }
        }
    }

    /// "COL 87¢"-style label: team abbreviation from results when the name matches,
    /// otherwise the first three letters. "Draw" stays as-is.
    private func shortLabel(for outcomeTitle: String) -> String {
        if outcomeTitle.caseInsensitiveCompare("Draw") == .orderedSame { return "Draw" }
        if let team = result?.teams.first(where: { $0.name.caseInsensitiveCompare(outcomeTitle) == .orderedSame }),
           let abbreviation = team.abbreviation {
            return abbreviation
        }
        return String(outcomeTitle.prefix(3)).uppercased()
    }
}
