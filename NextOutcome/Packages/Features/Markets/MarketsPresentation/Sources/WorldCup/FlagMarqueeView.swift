//
//  FlagMarqueeView.swift
//  NextOutcome
//
//  Created by Sok Pich on 04/07/2026.
//

import SwiftUI
import MarketsDomain
import DesignSystem

/// Header flags arranged on a slowly rotating half-circle — a wheel whose centre sits below
/// the strip, so only the top arc shows. Each country's win % rides its flag; eliminated
/// countries appear dimmed and grayscaled with an "OUT" label. Fed by the tournament-winner
/// market's per-country outcomes.
struct FlagMarqueeView: View {
    /// One flag tile on the marquee.
    struct Tile: Identifiable {
        /// Stable identity (the source market id).
        let id: String
        /// The caption riding the flag (win % or "OUT").
        let caption: String
        /// The flag image, if any.
        let imageURL: URL?
        /// Whether the country is eliminated (dimmed/grayscaled).
        let isOut: Bool
    }

    /// The tiles to display on the arc.
    let tiles: [Tile]

    /// One tile per country market: caption is the win %, or "OUT" once its market has
    /// resolved to No (the team is eliminated). Placeholder (inactive) slots are dropped.
    /// Eliminated tiles are spread evenly through the still-alive ones so the arc always
    /// shows a mix rather than a cluster of "OUT".
    /// - Parameters:
    ///   - winnerEvent: The tournament-winner futures event.
    ///   - max: The maximum number of tiles.
    /// - Returns: The interleaved (alive + eliminated) tiles.
    static func tiles(from winnerEvent: Event?, max: Int = 20) -> [Tile] {
        guard let winnerEvent else { return [] }
        let ranked = winnerEvent.markets
            .filter { $0.isActive && $0.yesOutcome != nil }
            .sorted { ($0.yesOutcome?.price ?? 0) > ($1.yesOutcome?.price ?? 0) }
            .prefix(max)
            .map { market -> Tile in
                let price = market.yesOutcome?.price ?? 0
                let isOut = market.isResolved && price < 0.5
                let caption = isOut
                    ? "OUT"
                    : (price < 0.01 ? "<1%" : MarketFormatting.percent(price))
                return Tile(id: market.id, caption: caption, imageURL: market.imageURL, isOut: isOut)
            }
        return interleave(alive: ranked.filter { !$0.isOut }, out: ranked.filter(\.isOut))
    }

    /// Distributes `out` tiles at even fractional positions among the `alive` tiles.
    private static func interleave(alive: [Tile], out: [Tile]) -> [Tile] {
        guard !out.isEmpty else { return alive }
        guard !alive.isEmpty else { return out }
        let total = alive.count + out.count
        var result: [Tile] = []
        var ai = 0, oi = 0
        for i in 0..<total {
            let takeOut = oi < out.count
                && Double(oi + 1) / Double(out.count) <= Double(i + 1) / Double(total)
            if takeOut || ai >= alive.count {
                result.append(out[oi]); oi += 1
            } else {
                result.append(alive[ai]); ai += 1
            }
        }
        return result
    }

    /// Whether the user has reduce-motion enabled (freezes the marquee).
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The overall strip height.
    private static let stripHeight: CGFloat = 140
    /// The y of the centre (highest) flag.
    private static let apexY: CGFloat = 42      // y of the centre (highest) flag
    /// How much lower the edge flags sit than the apex.
    private static let arcDepth: CGFloat = 30   // how much lower the edge flags sit
    /// The maximum tile tilt at the arc's edges.
    private static let tiltDegrees: Double = 15
    /// The marquee scroll speed in points per second.
    private static let pointsPerSecond: Double = 16

    var body: some View {
        if !tiles.isEmpty {
            GeometryReader { geo in
                if reduceMotion {
                    conveyor(width: geo.size.width, offset: 0)
                } else {
                    TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                        let offset = context.date.timeIntervalSinceReferenceDate * Self.pointsPerSecond
                        conveyor(width: geo.size.width, offset: offset)
                    }
                }
            }
            .frame(height: Self.stripHeight)
            .clipped()
            .accessibilityHidden(true) // decorative
        }
    }

    /// A horizontal conveyor of two tile copies scrolling left (seamless via modulo), with a
    /// parabolic dome applied by screen x — the centre flag rides highest and edges dip, so a
    /// flag is always crossing the top-centre (no apex gap) and each tile tilts with the arc.
    private func conveyor(width: CGFloat, offset: Double) -> some View {
        let spacing = width / 4.2
        let contentWidth = spacing * CGFloat(tiles.count)
        let scroll = CGFloat(offset.truncatingRemainder(dividingBy: Double(contentWidth)))

        return ZStack {
            ForEach(0..<2, id: \.self) { copy in
                ForEach(Array(tiles.enumerated()), id: \.element.id) { index, tile in
                    let x = CGFloat(copy) * contentWidth
                        + CGFloat(index) * spacing + spacing / 2 - scroll
                    let t = (x - width / 2) / (width / 2)          // -1 … 1 across the screen
                    tileView(tile)
                        .rotationEffect(.degrees(Self.tiltDegrees * Double(t)))
                        .position(x: x, y: Self.apexY + Self.arcDepth * t * t)
                        .opacity(x >= -spacing && x <= width + spacing ? 1 : 0)
                }
            }
        }
    }

    /// Renders one tile: the flag image (grayscaled/dimmed when out) above its caption.
    /// - Parameter tile: The tile to render.
    private func tileView(_ tile: Tile) -> some View {
        VStack(spacing: 4) {
            AsyncImage(url: tile.imageURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                RoundedRectangle(cornerRadius: DSLayout.chipRadius).fill(DSColor.surface)
            }
            .frame(width: 52, height: 38)
            .clipShape(RoundedRectangle(cornerRadius: DSLayout.chipRadius))
            .grayscale(tile.isOut ? 1 : 0)
            .opacity(tile.isOut ? 0.55 : 1)
            .shadow(color: .black.opacity(0.4), radius: 4, y: 2)

            Text(tile.caption)
                .font(DSFont.caption2.bold())
                .foregroundStyle(tile.isOut ? DSColor.textSecondary : DSColor.textPrimary)
        }
        .frame(width: 64)
    }
}

#if DEBUG
#Preview {
    FlagMarqueeView(tiles: [
        .init(id: "1", caption: "35%", imageURL: nil, isOut: false),
        .init(id: "2", caption: "17%", imageURL: nil, isOut: false),
        .init(id: "3", caption: "OUT", imageURL: nil, isOut: true),
        .init(id: "4", caption: "7%", imageURL: nil, isOut: false),
        .init(id: "5", caption: "<1%", imageURL: nil, isOut: false),
        .init(id: "6", caption: "6%", imageURL: nil, isOut: false),
        .init(id: "7", caption: "OUT", imageURL: nil, isOut: true),
    ])
    .background(DSColor.background)
}
#endif
