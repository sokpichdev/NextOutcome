//
//  ActivityRow.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import SwiftUI
import PortfolioDomain
import DesignSystem

struct ActivityRow: View {
    let activity: Activity

    var body: some View {
        DSCard {
            HStack(alignment: .top, spacing: DSLayout.spacing) {
                icon
                VStack(alignment: .leading, spacing: 4) {
                    Text(activity.title)
                        .font(DSFont.subheadline)
                        .foregroundStyle(DSColor.textPrimary)
                        .lineLimit(2)
                    HStack(spacing: 6) {
                        StatusBadge(activity.kind.label, color: kindColor)
                        if !activity.outcome.isEmpty {
                            Text(activity.outcome)
                                .font(DSFont.caption)
                                .foregroundStyle(DSColor.textSecondary)
                        }
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(PortfolioFormatting.usd(activity.usdcSize))
                        .font(DSFont.caption.bold())
                        .foregroundStyle(activity.isCredit ? DSColor.positive : DSColor.textPrimary)
                    Text(relativeTime)
                        .font(DSFont.caption2)
                        .foregroundStyle(DSColor.textSecondary)
                }
            }
        }
    }

    private var kindColor: Color {
        switch activity.kind {
        case .buy: return DSColor.positive
        case .sell, .redeem: return DSColor.negative
        default: return DSColor.accent
        }
    }

    private var relativeTime: String {
        activity.timestamp.formatted(.relative(presentation: .numeric))
    }

    @ViewBuilder
    private var icon: some View {
        if let url = activity.iconURL {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                DSColor.surfaceElevated
            }
            .frame(width: DSLayout.iconsize, height: DSLayout.iconsize)
            .clipShape(RoundedRectangle(cornerRadius: DSLayout.chipRadius))
        } else {
            RoundedRectangle(cornerRadius: DSLayout.chipRadius)
                .fill(DSColor.surfaceElevated)
                .frame(width: DSLayout.iconsize, height: DSLayout.iconsize)
        }
    }
}
