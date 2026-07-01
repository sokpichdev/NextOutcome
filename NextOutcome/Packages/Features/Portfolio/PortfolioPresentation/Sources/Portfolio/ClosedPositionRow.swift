//
//  ClosedPositionRow.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import SwiftUI
import PortfolioDomain
import DesignSystem

struct ClosedPositionRow: View {
    let position: ClosedPosition

    var body: some View {
        DSCard {
            HStack(alignment: .top, spacing: DSLayout.spacing) {
                icon
                VStack(alignment: .leading, spacing: 4) {
                    Text(position.title)
                        .font(DSFont.subheadline)
                        .foregroundStyle(DSColor.textPrimary)
                        .lineLimit(2)
                    if !position.outcome.isEmpty {
                        StatusBadge(position.outcome, color: DSColor.textSecondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(PortfolioFormatting.signedUSD(position.realizedPnl))
                        .font(DSFont.caption.bold())
                        .foregroundStyle(position.isProfitable ? DSColor.positive : DSColor.negative)
                    Text(PortfolioFormatting.signedPercent(position.percentRealizedPnl))
                        .font(DSFont.caption2)
                        .foregroundStyle(DSColor.textSecondary)
                }
            }
        }
    }

    @ViewBuilder
    private var icon: some View {
        if let url = position.iconURL {
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
