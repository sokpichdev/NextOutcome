//
//  OrderbookDepthView.swift
//  NextOutcome
//
//  Created by Sok Pich on 30/06/2026.
//

import SwiftUI

/// A single price level in an order book depth display, ready for direct
/// rendering (values are already formatted strings, not raw numbers).
public struct DepthLevel: Identifiable {
    /// A unique identifier so SwiftUI can diff rows in a `ForEach`.
    public let id = UUID()
    /// The formatted price for this level, e.g. "0.62".
    public let price: String
    /// The formatted size (quantity) available at this level, e.g. "1,204".
    public let size: String
    /// This level's size relative to the largest size on its side of the book,
    /// from 0 to 1. Drives how wide the colored depth bar is drawn.
    public let fraction: Double // 0...1 relative to max size in the book side

    /// Creates a depth level.
    /// - Parameters:
    ///   - price: The formatted price string.
    ///   - size: The formatted size string.
    ///   - fraction: The relative size (0 to 1) used to size the depth bar.
    public init(price: String, size: String, fraction: Double) {
        self.price = price
        self.size = size
        self.fraction = fraction
    }
}

/// Renders a two-column order book depth chart: bids (buy orders, green) on the
/// left and asks (sell orders, red) on the right, each row's background bar
/// sized proportionally to its size relative to the deepest level on that side.
public struct OrderbookDepthView: View {
    /// The buy-side price levels, typically ordered from best (highest) to worst.
    let bids: [DepthLevel]
    /// The sell-side price levels, typically ordered from best (lowest) to worst.
    let asks: [DepthLevel]

    /// Creates the depth view.
    /// - Parameters:
    ///   - bids: The bid-side levels to display.
    ///   - asks: The ask-side levels to display.
    public init(bids: [DepthLevel], asks: [DepthLevel]) {
        self.bids = bids
        self.asks = asks
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // bids (green, right-algineed depth bar)
            VStack(spacing: 4) {
                ForEach(bids) { level in
                    DepthRow(level: level, side: .bid)
                }
            }
            // asks (red, left-aligned depth bar)
            VStack(spacing: 4) {
                ForEach(asks) { level in
                    DepthRow(level: level, side: .ask)
                }
            }
        }
    }
}

/// A single row within `OrderbookDepthView`: a colored depth bar behind the
/// price and size text, sized according to the level's `fraction`.
private struct DepthRow: View {
    /// Which side of the book this row belongs to, controlling color and bar
    /// alignment (bids fill from the trailing edge, asks from the leading edge).
    enum Side { case bid, ask }
    /// The price level data to render.
    let level: DepthLevel
    /// Which side of the book this row represents.
    let side: Side

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: side == .bid ? .trailing : .leading) {
                (side == .bid ? DSColor.positiveTint : DSColor.negativeTint)
                    .frame(width: geo.size.width * level.fraction)
                
                HStack {
                    Text(level.price)
                        .foregroundStyle(side == .bid ? DSColor.positive : DSColor.negative)
                    Spacer()
                    Text(level.size)
                        .foregroundStyle(DSColor.textSecondary)
                }
                .font(DSFont.priceSmall)
                .padding(.horizontal, 6)
            }
        }
        .frame(height: 22)
    }
}
