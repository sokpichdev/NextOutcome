//
//  ActivityRow.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import SwiftUI
import PortfolioDomain
import DesignSystem

/// A card row for one activity entry: icon, title, a kind badge (colour-coded), the USD
/// amount, and a relative timestamp.
struct ActivityRow: View {
    /// The activity entry to render.
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

    /// The badge colour for the activity kind (green buy, red sell/redeem, accent otherwise).
    private var kindColor: Color {
        switch activity.kind {
        case .buy: return DSColor.positive
        case .sell, .redeem: return DSColor.negative
        default: return DSColor.accent
        }
    }

    /// The timestamp rendered as a relative string (e.g. "2 hr ago").
    private var relativeTime: String {
        activity.timestamp.formatted(.relative(presentation: .numeric))
    }

    /// The market icon, loaded async with a placeholder, or a plain rounded rectangle when
    /// there's no icon URL.
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
