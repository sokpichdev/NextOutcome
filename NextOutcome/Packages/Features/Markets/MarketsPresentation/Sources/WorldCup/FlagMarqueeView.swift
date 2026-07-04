//
//  FlagMarqueeView.swift
//  NextOutcome
//
//  Created by Sok Pich on 04/07/2026.
//

import SwiftUI
import MarketsDomain
import DesignSystem

/// Decorative strip of tilted flag tiles with win percentages, fed by the tournament-winner
/// market's outcomes. Static in this phase; the looping animation lands with the polish pass.
struct FlagMarqueeView: View {
    struct Tile: Identifiable {
        let id: String
        let caption: String
        let imageURL: URL?
    }

    let tiles: [Tile]

    /// Top contenders from the winner event: one tile per country market, caption = win %.
    static func tiles(from winnerEvent: Event?, max: Int = 10) -> [Tile] {
        guard let winnerEvent else { return [] }
        return winnerEvent.markets
            .filter { $0.isActive && $0.yesOutcome != nil }
            .sorted { ($0.yesOutcome?.price ?? 0) > ($1.yesOutcome?.price ?? 0) }
            .prefix(max)
            .map { market in
                let price = market.yesOutcome?.price ?? 0
                let caption = price < 0.01 ? "<1%" : MarketFormatting.percent(price)
                return Tile(id: market.id, caption: caption, imageURL: market.imageURL)
            }
    }

    var body: some View {
        if !tiles.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DSLayout.spacingXLarge) {
                    ForEach(Array(tiles.enumerated()), id: \.element.id) { index, tile in
                        tileView(tile, index: index)
                    }
                }
                .padding(.horizontal, DSLayout.spacingXLarge)
                .padding(.vertical, DSLayout.spacingLarge)
            }
            .disabled(true) // decorative
        }
    }

    private func tileView(_ tile: Tile, index: Int) -> some View {
        VStack(spacing: DSLayout.spacingXSmall) {
            AsyncImage(url: tile.imageURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                RoundedRectangle(cornerRadius: DSLayout.chipRadius).fill(DSColor.surface)
            }
            .frame(width: 56, height: 40)
            .clipShape(RoundedRectangle(cornerRadius: DSLayout.chipRadius))
            .shadow(color: .black.opacity(0.4), radius: 4, y: 2)

            Text(tile.caption)
                .font(DSFont.caption)
                .foregroundStyle(DSColor.textSecondary)
        }
        .rotationEffect(.degrees(index.isMultiple(of: 2) ? -7 : 6))
        .offset(y: index.isMultiple(of: 2) ? 0 : 10)
    }
}
