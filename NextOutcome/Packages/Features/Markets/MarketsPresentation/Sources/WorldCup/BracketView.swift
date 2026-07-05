//
//  BracketView.swift
//  NextOutcome
//
//  Created by Sok Pich on 04/07/2026.
//

import SwiftUI
import MarketsDomain
import DesignSystem

/// The hub's Bracket tab: a round carousel (Groups → Round of 16 → Quarter-finals →
/// Semi-finals → Final). Groups shows advance odds, the live round shows match cards with
/// win %, and later rounds are TBD until their fixtures are set.
struct BracketView: View {
    let games: [Event]
    let completedGames: [Event]
    let results: [String: GameResult]
    let props: [Event]
    let groupEvents: [Event]
    let teams: [String: GameTeam]

    @State private var index = 0

    private var pages: [BracketPage] {
        BracketBuilder.pages(games: games, completedGames: completedGames, results: results,
                             props: props, groupEvents: groupEvents, teams: teams)
    }

    var body: some View {
        let pages = pages
        if pages.isEmpty {
            ContentUnavailableView("No bracket yet", systemImage: "chart.bar.doc.horizontal")
                .padding(.vertical, DSLayout.spacingXLarge)
        } else {
            let current = min(index, pages.count - 1)
            VStack(spacing: DSLayout.spacing) {
                roundHeader(pages: pages, current: current)
                pageContent(pages[current])
            }
        }
    }

    private func roundHeader(pages: [BracketPage], current: Int) -> some View {
        HStack {
            chevron("chevron.left", enabled: current > 0) { index = current - 1 }
            Spacer()
            Text(pages[current].title)
                .font(DSFont.headline.bold())
                .foregroundStyle(DSColor.textPrimary)
            Spacer()
            chevron("chevron.right", enabled: current < pages.count - 1) { index = current + 1 }
        }
        .padding(.vertical, DSLayout.spacingSmall)
    }

    private func chevron(_ system: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.headline)
                .foregroundStyle(enabled ? DSColor.textPrimary : DSColor.textSecondary.opacity(0.4))
                .frame(width: 40, height: 40)
        }
        .disabled(!enabled)
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func pageContent(_ page: BracketPage) -> some View {
        switch page {
        case .groups(let data):
            if data.standings.isEmpty {
                AdvanceBoardCard(rows: data.advance)
            } else {
                VStack(spacing: DSLayout.spacing) {
                    ForEach(data.standings) { GroupCard(standing: $0) }
                }
            }
        case .matches(_, let matches):
            VStack(spacing: DSLayout.spacing) {
                ForEach(matches) { BracketMatchCard(match: $0) }
            }
        case .placeholder(let title):
            BracketPlaceholderCard(title: title)
        }
    }
}

/// One group's card: its teams (from the group-winner market) with each team's chance to
/// reach the quarter-finals. The public feed has no group points table, so the advance % —
/// not a points column — is the meaningful per-team number.
private struct GroupCard: View {
    let standing: GroupStanding

    var body: some View {
        VStack(alignment: .leading, spacing: DSLayout.spacing) {
            Text(standing.name)
                .font(DSFont.subheadline.bold())
                .foregroundStyle(DSColor.textPrimary)

            ForEach(standing.teams) { team in
                HStack(spacing: DSLayout.spacingMedium) {
                    FlagThumb(url: team.logoURL, name: team.name)
                    Text(team.name)
                        .font(DSFont.subheadline)
                        .foregroundStyle(team.isOut ? DSColor.textSecondary : DSColor.textPrimary)
                        .lineLimit(1)
                    Spacer()
                    advanceLabel(team)
                }
                if team.id != standing.teams.last?.id { Divider().overlay(DSColor.separator) }
            }
        }
        .padding(DSLayout.margin)
        .background(DSColor.surface.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: DSLayout.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: DSLayout.cardRadius)
                .strokeBorder(DSColor.surfaceElevated, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func advanceLabel(_ team: GroupTeam) -> some View {
        if team.isOut {
            Text("OUT")
                .font(DSFont.caption.bold())
                .foregroundStyle(DSColor.textSecondary)
        } else if let pct = team.advancePercent {
            let color = Color(hexString: team.colorHex) ?? DSColor.accent
            Text(MarketFormatting.percent(Decimal(pct)))
                .font(DSFont.caption.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, DSLayout.spacingMedium)
                .padding(.vertical, DSLayout.spacingXSmall)
                .background(pct >= 0.999 ? DSColor.accent : color)
                .clipShape(Capsule())
        }
    }
}

/// "Advance to the Quarter-finals" odds board — flat fallback when per-group markets are absent.
private struct AdvanceBoardCard: View {
    let rows: [AdvanceRow]

    var body: some View {
        VStack(alignment: .leading, spacing: DSLayout.spacing) {
            Text("Chance to reach the Quarter-finals")
                .font(DSFont.subheadline.bold())
                .foregroundStyle(DSColor.textPrimary)

            ForEach(rows) { row in
                HStack(spacing: DSLayout.spacingMedium) {
                    FlagThumb(url: row.logoURL, name: row.name)
                    Text(row.name)
                        .font(DSFont.subheadline)
                        .foregroundStyle(DSColor.textPrimary)
                        .lineLimit(1)
                    Spacer()
                    Text(MarketFormatting.percent(Decimal(row.percent)))
                        .font(DSFont.priceSmall.bold())
                        .foregroundStyle(DSColor.textPrimary)
                        .frame(minWidth: 44, alignment: .trailing)
                }
                if row.id != rows.last?.id { Divider().overlay(DSColor.separator) }
            }
        }
        .padding(DSLayout.margin)
        .background(DSColor.surface.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: DSLayout.cardRadius))
    }
}

/// A knockout match: matchup + kickoff/status, and a row per team with win % (upcoming) or
/// score (final), plus a team-coloured progress underline.
private struct BracketMatchCard: View {
    let match: BracketMatch

    var body: some View {
        VStack(alignment: .leading, spacing: DSLayout.spacing) {
            VStack(alignment: .leading, spacing: 2) {
                Text(match.title)
                    .font(DSFont.subheadline.bold())
                    .foregroundStyle(DSColor.textPrimary)
                Text(subtitle)
                    .font(DSFont.caption)
                    .foregroundStyle(match.status == .live ? DSColor.negative : DSColor.textSecondary)
            }
            teamRow(match.home)
            teamRow(match.away)
        }
        .padding(DSLayout.margin)
        .background(DSColor.surface.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: DSLayout.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: DSLayout.cardRadius)
                .strokeBorder(DSColor.surfaceElevated, lineWidth: 1)
        )
    }

    private var subtitle: String {
        switch match.status {
        case .final: return "Final"
        case .live:  return "Live"
        case .scheduled:
            guard let kickoff = match.kickoff else { return "Scheduled" }
            return kickoff.formatted(.dateTime.month(.abbreviated).day().hour().minute())
        }
    }

    @ViewBuilder
    private func teamRow(_ team: BracketTeam?) -> some View {
        if let team {
            let color = Color(hexString: team.colorHex) ?? DSColor.accent
            VStack(spacing: 6) {
                HStack(spacing: DSLayout.spacingMedium) {
                    FlagThumb(url: team.logoURL, name: team.name)
                    Text(team.name)
                        .font(DSFont.subheadline.bold())
                        .foregroundStyle(team.isWinner || match.status != .final ? DSColor.textPrimary : DSColor.textSecondary)
                        .lineLimit(1)
                    Spacer()
                    trailing(team, color: color)
                }
                progressUnderline(team, color: color)
            }
        }
    }

    @ViewBuilder
    private func trailing(_ team: BracketTeam, color: Color) -> some View {
        if let win = team.winPercent {
            Text(MarketFormatting.percent(Decimal(win)))
                .font(DSFont.caption.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, DSLayout.spacingMedium)
                .padding(.vertical, DSLayout.spacingXSmall)
                .background(color)
                .clipShape(Capsule())
        } else if let score = team.score {
            Text("\(score)")
                .font(DSFont.subheadline.bold())
                .foregroundStyle(DSColor.textPrimary)
                .frame(width: 28, height: 28)
                .background(DSColor.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func progressUnderline(_ team: BracketTeam, color: Color) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(DSColor.separator).frame(height: 2)
                Capsule().fill(color)
                    .frame(width: geo.size.width * fillFraction(team), height: 2)
            }
        }
        .frame(height: 2)
    }

    private func fillFraction(_ team: BracketTeam) -> Double {
        if let win = team.winPercent { return max(0, min(1, win)) }
        return team.isWinner ? 1 : 0
    }
}

/// TBD card for rounds whose fixtures aren't set yet.
private struct BracketPlaceholderCard: View {
    let title: String

    var body: some View {
        VStack(spacing: DSLayout.spacing) {
            ForEach(0..<2, id: \.self) { _ in
                HStack(spacing: DSLayout.spacingMedium) {
                    RoundedRectangle(cornerRadius: 6).fill(DSColor.surfaceElevated).frame(width: 28, height: 20)
                    Text("TBD").font(DSFont.subheadline).foregroundStyle(DSColor.textSecondary)
                    Spacer()
                }
            }
        }
        .padding(DSLayout.margin)
        .frame(maxWidth: .infinity)
        .background(DSColor.surface.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: DSLayout.cardRadius))
        .overlay(alignment: .top) {
            Text("\(title) fixtures are set after the previous round")
                .font(DSFont.caption)
                .foregroundStyle(DSColor.textSecondary)
                .padding(.top, DSLayout.spacingXLarge + DSLayout.spacing)
        }
    }
}

/// Small flag thumbnail with a monogram fallback.
private struct FlagThumb: View {
    let url: URL?
    let name: String

    var body: some View {
        AsyncImage(url: url) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            RoundedRectangle(cornerRadius: 4)
                .fill(DSColor.surfaceElevated)
                .overlay(Text(name.prefix(1)).font(DSFont.caption2.bold()).foregroundStyle(DSColor.textSecondary))
        }
        .frame(width: 26, height: 18)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
