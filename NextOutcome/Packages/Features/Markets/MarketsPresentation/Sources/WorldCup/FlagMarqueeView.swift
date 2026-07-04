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
    struct Tile: Identifiable {
        let id: String
        let caption: String
        let imageURL: URL?
        let isOut: Bool
    }

    let tiles: [Tile]

    /// One tile per country market: caption is the win %, or "OUT" once its market has
    /// resolved to No (the team is eliminated). Placeholder (inactive) slots are dropped.
    /// Eliminated tiles are spread evenly through the still-alive ones so the arc always
    /// shows a mix rather than a cluster of "OUT".
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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let stripHeight: CGFloat = 150
    private static let radius: CGFloat = 330
    private static let windowDegrees: Double = 42    // half-span of the visible arc
    private static let degreesPerSecond: Double = 5

    var body: some View {
        if !tiles.isEmpty {
            GeometryReader { geo in
                if reduceMotion {
                    arc(width: geo.size.width, phase: 0)
                } else {
                    TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                        let phase = context.date.timeIntervalSinceReferenceDate * Self.degreesPerSecond
                        arc(width: geo.size.width, phase: phase)
                    }
                }
            }
            .frame(height: Self.stripHeight)
            .clipped()
            .accessibilityHidden(true) // decorative
        }
    }

    /// Places every tile on the ring at its current angle. All tiles are always rendered
    /// (opacity gates visibility) so their flag images keep identity and never reload as
    /// they rotate through the window.
    private func arc(width: CGFloat, phase: Double) -> some View {
        let spacing = 360.0 / Double(tiles.count)
        let centerX = width / 2
        let centerY = Self.radius + 14 // apex ~14pt below the top edge

        return ZStack {
            ForEach(Array(tiles.enumerated()), id: \.element.id) { index, tile in
                let angle = normalize(Double(index) * spacing + phase) // 0 = top of the ring
                let radians = angle * .pi / 180
                tileView(tile)
                    .rotationEffect(.degrees(angle))
                    .position(
                        x: centerX + Self.radius * sin(radians),
                        y: centerY - Self.radius * cos(radians)
                    )
                    .opacity(opacity(for: angle))
            }
        }
    }

    /// Normalise degrees to -180…180 so 0 is the top of the ring.
    private func normalize(_ degrees: Double) -> Double {
        var d = degrees.truncatingRemainder(dividingBy: 360)
        if d > 180 { d -= 360 }
        if d < -180 { d += 360 }
        return d
    }

    /// Fade tiles out as they reach the clipped edges of the visible arc.
    private func opacity(for angle: Double) -> Double {
        let t = abs(angle) / Self.windowDegrees
        guard t <= 1 else { return 0 }
        return t > 0.8 ? (1 - t) / 0.2 : 1
    }

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
