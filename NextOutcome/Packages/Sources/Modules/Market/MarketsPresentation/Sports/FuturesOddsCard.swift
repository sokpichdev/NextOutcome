//
//  FuturesOddsCard.swift
//  NextOutcome
//
//  Created by Sok Pich on 06/07/2026.
//

import SwiftUI
import MarketsDomain
import DesignSystem

/// One Futures market's ranked outcome breakdown (e.g. "NBA Champion"): each candidate's
/// probability as a percent-scaled bar, highest first, with a "Show More" expander past 5.
struct FuturesOddsCard: View {
    /// The futures event (e.g. "NBA Champion", "NBA MVP").
    let event: Event
    /// Cycled bar colors for the ranked rows.
    private static let barColors: [Color] = [.orange, .blue, .pink, .purple, .teal, .yellow, .green, .red]

    @State private var isExpanded = false

    private var ranked: [Market] {
        event.markets.sorted { ($0.yesOutcome?.price ?? 0) > ($1.yesOutcome?.price ?? 0) }
    }

    var body: some View {
        DSCard {
            VStack(alignment: .leading, spacing: DSLayout.spacingSmall) {
                Text(event.title)
                    .font(DSFont.title3.bold())
                    .foregroundStyle(DSColor.textPrimary)

                let visible = isExpanded ? ranked : Array(ranked.prefix(5))
                ForEach(Array(visible.enumerated()), id: \.element.id) { index, market in
                    row(market, color: Self.barColors[index % Self.barColors.count])
                }

                if ranked.count > 5 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
                    } label: {
                        HStack(spacing: 4) {
                            Text(isExpanded ? "Show Less" : "Show More")
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        }
                        .font(DSFont.caption.bold())
                        .foregroundStyle(DSColor.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    /// One ranked row: label, percent, and a bar scaled to the outcome's probability.
    private func row(_ market: Market, color: Color) -> some View {
        let percent = market.yesOutcome?.price ?? 0
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(market.groupItemTitle ?? market.question)
                    .font(DSFont.subheadline)
                    .foregroundStyle(DSColor.textPrimary)
                    .lineLimit(1)
                Spacer()
                Text(MarketFormatting.percent(percent))
                    .font(DSFont.subheadline.bold())
                    .foregroundStyle(DSColor.textPrimary)
            }
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 3)
                    .fill(color)
                    .frame(width: max(geo.size.width * CGFloat(truncating: percent as NSNumber), 3), height: 6)
            }
            .frame(height: 6)
        }
    }
}
