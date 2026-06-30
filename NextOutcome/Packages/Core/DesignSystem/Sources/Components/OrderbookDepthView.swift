//
//  OrderbookDepthView.swift
//  NextOutcome
//
//  Created by Sok Pich on 30/06/2026.
//

import SwiftUI

public struct DepthLevel: Identifiable {
    public let id = UUID()
    public let price: String
    public let size: String
    public let fraction: Double // 0...1 relative to max size in the book side
    
    public init(price: String, size: String, fraction: Double) {
        self.price = price
        self.size = size
        self.fraction = fraction
    }
}

public struct OrderbookDepthView: View {
    let bids: [DepthLevel]
    let asks: [DepthLevel]
    
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

private struct DepthRow: View {
    enum Side { case bid, ask }
    let level: DepthLevel
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
