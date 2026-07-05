//
//  LeaderboardRow.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import SwiftUI
import PortfolioDomain
import DesignSystem

/// A card row for one leaderboard entry: rank (top 3 accented), avatar, name, and the
/// ranked amount (green when ranking by profit).
struct LeaderboardRow: View {
    /// The entry to render.
    let entry: LeaderboardEntry
    /// The active ranking metric, used to colour the amount.
    let metric: LeaderboardMetric

    var body: some View {
        DSCard {
            HStack(spacing: DSLayout.spacing) {
                Text("\(entry.rank)")
                    .font(DSFont.headline)
                    .foregroundStyle(rankColor)
                    .frame(width: 28, alignment: .leading)

                avatar
                Text(entry.name)
                    .font(DSFont.subheadline)
                    .foregroundStyle(DSColor.textPrimary)
                    .lineLimit(1)
                Spacer()
                Text(PortfolioFormatting.usd(entry.amount))
                    .font(DSFont.caption.bold())
                    .foregroundStyle(metric == .profit ? DSColor.positive : DSColor.textPrimary)
            }
        }
    }

    /// Accent colour for the top-3 ranks, muted for the rest.
    private var rankColor: Color {
        switch entry.rank {
        case 1, 2, 3: return DSColor.accent
        default: return DSColor.textSecondary
        }
    }

    /// The trader's circular avatar, loaded async with a placeholder, or a plain circle
    /// when there's no image URL.
    @ViewBuilder
    private var avatar: some View {
        if let url = entry.profileImageURL {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                DSColor.surfaceElevated
            }
            .frame(width: 30, height: 30)
            .clipShape(Circle())
        } else {
            Circle().fill(DSColor.surfaceElevated).frame(width: 30, height: 30)
        }
    }
}
