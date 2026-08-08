//
//  MoverRow.swift
//  NextOutcome
//
//  Created by Sok Pich on 05/07/2026.
//

import SwiftUI
import MarketsDomain
import DesignSystem

/// One numbered row in the Breaking movers list: rank, icon, question, the current implied
/// chance (big), and the coloured 24h delta (▲ green up / ▼ red down).
struct MoverRow: View {
    /// The 1-based rank shown on the leading edge.
    let rank: Int
    /// The mover to display.
    let mover: Mover

    var body: some View {
        HStack(spacing: DSLayout.spacingMedium) {
            Text("\(rank)")
                .font(DSFont.subheadline)
                .foregroundStyle(DSColor.textSecondary)
                .frame(minWidth: 18, alignment: .center)

            icon

            Text(mover.question)
                .font(DSFont.subheadline)
                .foregroundStyle(DSColor.textPrimary)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 2) {
                Text(MarketFormatting.percent(mover.probability))
                    .font(DSFont.headline)
                    .foregroundStyle(DSColor.textPrimary)
                delta
            }

            Image(systemName: "chevron.right")
                .font(DSFont.caption)
                .foregroundStyle(DSColor.textSecondary)
        }
        .padding(.vertical, DSLayout.spacingSmall)
        .contentShape(Rectangle())
    }

    /// The mover's icon (parent event image), with a neutral placeholder while loading.
    private var icon: some View {
        AsyncImage(url: mover.imageURL) { $0.resizable().scaledToFill() } placeholder: { DSColor.surfaceElevated }
            .frame(width: 40, height: 40)
            .clipShape(RoundedRectangle(cornerRadius: DSLayout.spacingXSmall))
    }

    /// The 24h delta pill: an up/down arrow plus the move magnitude, tinted by direction.
    private var delta: some View {
        let points = Int((NSDecimalNumber(decimal: mover.magnitude).doubleValue * 100).rounded())
        let color = mover.isUp ? DSColor.positive : DSColor.negative
        return HStack(spacing: 1) {
            Image(systemName: mover.isUp ? "arrow.up.right" : "arrow.down.right")
            Text("\(points)%")
        }
        .font(DSFont.caption.bold())
        .foregroundStyle(color)
        .accessibilityLabel("\(mover.isUp ? "Up" : "Down") \(points) percent over 24 hours")
    }
}
