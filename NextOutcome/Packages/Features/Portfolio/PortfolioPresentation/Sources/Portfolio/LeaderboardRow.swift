//
//  LeaderboardRow.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import SwiftUI
import PortfolioDomain
import DesignSystem

struct LeaderboardRow: View {
    let entry: LeaderboardEntry
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

    private var rankColor: Color {
        switch entry.rank {
        case 1, 2, 3: return DSColor.accent
        default: return DSColor.textSecondary
        }
    }

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
