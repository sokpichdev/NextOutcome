//
//  EsportsTradeTicker.swift
//  NextOutcome
//
//  Created by Sok Pich on 14/07/2026.
//

import SwiftUI
import MarketsDomain
import DesignSystem

/// The hero card's single-line live-trades strip: "● LIVE TRADES  $288  Rayaya bought
/// LUA Gaming", auto-cycling through the recent trades.
struct EsportsTradeTicker: View {
    /// Recent trades, newest first.
    let trades: [ActivityTrade]
    /// The trade currently shown.
    @State private var index = 0

    var body: some View {
        HStack(spacing: DSLayout.spacingSmall) {
            Circle().fill(DSColor.negative).frame(width: 6, height: 6)
            Text("LIVE TRADES")
                .font(DSFont.caption2.bold())
                .foregroundStyle(DSColor.textPrimary)

            if let trade = currentTrade {
                Text(MarketFormatting.compactUSD(trade.size * trade.price))
                    .font(DSFont.caption.bold())
                    .foregroundStyle(trade.side == .buy ? DSColor.positive : DSColor.negative)
                avatar(trade)
                (Text(trade.actorName).bold().foregroundStyle(DSColor.textPrimary)
                    + Text(" \(trade.side == .buy ? "bought" : "sold") ").foregroundStyle(DSColor.textSecondary)
                    + Text(trade.outcome).bold().foregroundStyle(DSColor.textPrimary))
                    .font(DSFont.caption)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .id(index)
        .transition(.push(from: .bottom))
        .animation(.easeInOut(duration: 0.3), value: index)
        .task(id: trades.count) {
            // Cycle through the strip's trades every few seconds while visible.
            guard trades.count > 1 else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 3_500_000_000)
                guard !Task.isCancelled else { return }
                index += 1
            }
        }
    }

    private var currentTrade: ActivityTrade? {
        guard !trades.isEmpty else { return nil }
        return trades[index % trades.count]
    }

    @ViewBuilder
    private func avatar(_ trade: ActivityTrade) -> some View {
        AsyncImage(url: trade.avatarURL) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            Circle().fill(DSColor.surfaceElevated)
        }
        .frame(width: 18, height: 18)
        .clipShape(Circle())
    }
}
