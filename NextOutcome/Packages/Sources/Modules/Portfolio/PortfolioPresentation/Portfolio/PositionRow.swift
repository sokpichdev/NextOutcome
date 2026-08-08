//
//  PositionRow.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import SwiftUI
import PortfolioDomain
import DesignSystem

/// A card row for one open position: icon, title, outcome badge, and a value/shares/PnL
/// summary (PnL coloured green or red).
struct PositionRow: View {
    /// The position to render.
    let position: Position

    var body: some View {
        DSCard {
            VStack(alignment: .leading, spacing: DSLayout.spacing) {
                HStack(alignment: .top, spacing: DSLayout.spacing) {
                    icon
                    VStack(alignment: .leading, spacing: 4) {
                        Text(position.title)
                            .font(DSFont.subheadline)
                            .foregroundStyle(DSColor.textPrimary)
                            .lineLimit(2)
                        StatusBadge(position.outcome.isEmpty ? "—" : position.outcome, color: DSColor.accent)
                    }
                    Spacer()
                }

                HStack {
                    stat("Value", PortfolioFormatting.usd(position.currentValue))
                    Spacer()
                    stat("Shares", PortfolioFormatting.shares(position.size))
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("PnL")
                            .font(DSFont.caption2)
                            .foregroundStyle(DSColor.textSecondary)
                        Text(PortfolioFormatting.signedUSD(position.cashPnl)
                             + " (" + PortfolioFormatting.signedPercent(position.percentPnl) + ")")
                            .font(DSFont.caption.bold())
                            .foregroundStyle(position.isProfitable ? DSColor.positive : DSColor.negative)
                    }
                }
            }
        }
    }

    /// A small labelled value column (e.g. "Value" over "$12.34").
    /// - Parameters:
    ///   - label: The caption above the value.
    ///   - value: The formatted value string.
    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(DSFont.caption2)
                .foregroundStyle(DSColor.textSecondary)
            Text(value)
                .font(DSFont.caption.bold())
                .foregroundStyle(DSColor.textPrimary)
        }
    }

    /// The market icon, loaded async with a placeholder, or a plain rounded rectangle when
    /// there's no icon URL.
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
