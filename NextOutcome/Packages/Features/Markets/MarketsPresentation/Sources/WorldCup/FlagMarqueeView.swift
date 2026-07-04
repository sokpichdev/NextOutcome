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
/// market's outcomes. Loops slowly right-to-left; static under Reduce Motion.
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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var rowWidth: CGFloat = 0

    private static let pointsPerSecond: Double = 18
    private static let stripHeight: CGFloat = 84

    var body: some View {
        if !tiles.isEmpty {
            // The tile row is much wider than the screen, so it lives in an overlay on a
            // fixed-size strip — its width must never reach the surrounding layout.
            Color.clear
                .frame(height: Self.stripHeight)
                .frame(maxWidth: .infinity)
                .overlay(alignment: .leading) {
                    if reduceMotion {
                        tileRow
                    } else {
                        marquee
                    }
                }
                .clipped()
                .padding(.vertical, DSLayout.spacingSmall)
                .accessibilityHidden(true) // decorative
        }
    }

    /// Two copies of the row slide left; when the first copy has fully passed, the offset
    /// wraps (modulo row width) and the loop is seamless.
    private var marquee: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            let elapsed = context.date.timeIntervalSinceReferenceDate
            let offset = rowWidth > 0
                ? CGFloat(elapsed * Self.pointsPerSecond).truncatingRemainder(dividingBy: rowWidth)
                : 0

            HStack(spacing: 0) {
                tileRow
                    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { rowWidth = $0 }
                tileRow
            }
            .offset(x: -offset)
        }
    }

    private var tileRow: some View {
        HStack(spacing: DSLayout.spacingXLarge) {
            ForEach(Array(tiles.enumerated()), id: \.element.id) { index, tile in
                tileView(tile, index: index)
            }
        }
        .padding(.horizontal, DSLayout.spacingLarge)
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

#if DEBUG
#Preview {
    FlagMarqueeView(tiles: [
        .init(id: "1", caption: "35%", imageURL: nil),
        .init(id: "2", caption: "17%", imageURL: nil),
        .init(id: "3", caption: "13%", imageURL: nil),
        .init(id: "4", caption: "7%", imageURL: nil),
        .init(id: "5", caption: "<1%", imageURL: nil),
    ])
    .background(DSColor.background)
}
#endif
