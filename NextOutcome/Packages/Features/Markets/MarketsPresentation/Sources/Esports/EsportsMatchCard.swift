//
//  EsportsMatchCard.swift
//  NextOutcome
//
//  Created by Sok Pich on 14/07/2026.
//

import SwiftUI
import MarketsDomain
import DesignSystem

/// One row in the Games list: game header, match title, LIVE badge, two team rows
/// (logo, name, multiplier, % chip, brand-colour bar), and a footer with volume,
/// start time, and a local bookmark.
struct EsportsMatchCard: View {
    /// The match event.
    let event: Event
    /// The live result, when loaded.
    let result: GameResult?
    /// Locally-bookmarked event ids (visual only, matching web's bookmark icon).
    @AppStorage("esports.bookmarks") private var bookmarksData = Data()

    private var info: EsportsMatchInfo { EsportsMatchInfo(event: event, result: result) }

    var body: some View {
        VStack(alignment: .leading, spacing: DSLayout.spacing) {
            header
            if result?.live == true {
                HStack(spacing: DSLayout.spacingSmall) {
                    Circle().fill(DSColor.negative).frame(width: 6, height: 6)
                    Text("LIVE").font(DSFont.caption.bold()).foregroundStyle(DSColor.negative)
                }
            }
            teamRow(info.home)
            teamRow(info.away)
            footer
        }
        .padding(DSLayout.margin)
        .background(DSColor.surface.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: DSLayout.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: DSLayout.cardRadius)
                .strokeBorder(DSColor.surfaceElevated, lineWidth: 1)
        )
    }

    /// "⚙ Dota 2" game caption + match title.
    private var header: some View {
        VStack(alignment: .leading, spacing: DSLayout.spacingXSmall) {
            if let game = info.game {
                HStack(spacing: DSLayout.spacingXSmall) {
                    Image(systemName: game.glyph).font(.system(size: 11))
                    Text(game.fullName).font(DSFont.caption)
                }
                .foregroundStyle(DSColor.textSecondary)
            }
            Text(titleText)
                .font(DSFont.headline)
                .foregroundStyle(DSColor.textPrimary)
                .lineLimit(2)
        }
    }

    private var titleText: String {
        guard let title = info.title else { return event.title }
        return "\(title.homeTeam) vs \(title.awayTeam)"
    }

    /// One team's row + its brand-colour probability bar.
    private func teamRow(_ team: EsportsMatchInfo.Team) -> some View {
        VStack(alignment: .leading, spacing: DSLayout.spacingXSmall) {
            HStack(spacing: DSLayout.spacingMedium) {
                EsportsTeamLogo(url: team.logoURL, name: team.name)
                Text(team.name)
                    .font(DSFont.subheadline)
                    .foregroundStyle(DSColor.textPrimary)
                    .lineLimit(1)
                Spacer()
                if let score = team.seriesScore, result?.live == true || result?.ended == true {
                    Text("\(score)")
                        .font(DSFont.subheadline.bold())
                        .foregroundStyle(DSColor.textPrimary)
                }
                if let price = team.price, let multiplier = EsportsHubViewModel.multiplier(forPrice: price) {
                    Text(multiplier)
                        .font(DSFont.caption)
                        .foregroundStyle(DSColor.textSecondary)
                }
                if let price = team.price {
                    Text(MarketFormatting.percent(price))
                        .font(DSFont.subheadline.bold())
                        .foregroundStyle(DSColor.textPrimary)
                        .padding(.horizontal, DSLayout.spacingMedium)
                        .padding(.vertical, DSLayout.spacingXSmall)
                        .background(DSColor.surfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            if let price = team.price {
                EsportsTeamBar(
                    fraction: NSDecimalNumber(decimal: price).doubleValue,
                    color: Color(hexString: team.colorHex) ?? DSColor.accent
                )
            }
        }
    }

    /// "$4M Vol. · 6:10 PM" + bookmark toggle.
    private var footer: some View {
        HStack(spacing: DSLayout.spacingSmall) {
            Text("\(MarketFormatting.compactUSD(event.volume)) Vol.")
            if let start = event.gameStartTime {
                Text("·")
                Text(start, format: .dateTime.hour().minute())
            }
            Spacer()
            Button {
                toggleBookmark()
            } label: {
                Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                    .foregroundStyle(isBookmarked ? DSColor.accent : DSColor.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .font(DSFont.caption)
        .foregroundStyle(DSColor.textSecondary)
    }

    // MARK: bookmarks (local only)

    private var bookmarks: Set<String> {
        (try? JSONDecoder().decode(Set<String>.self, from: bookmarksData)) ?? []
    }

    private var isBookmarked: Bool { bookmarks.contains(event.id) }

    private func toggleBookmark() {
        var set = bookmarks
        if !set.insert(event.id).inserted { set.remove(event.id) }
        bookmarksData = (try? JSONEncoder().encode(set)) ?? Data()
    }
}
