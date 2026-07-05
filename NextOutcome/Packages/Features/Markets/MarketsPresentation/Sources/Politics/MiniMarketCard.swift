//
//  MiniMarketCard.swift
//  NextOutcome
//
//  Created by Sok Pich on 05/07/2026.
//

import SwiftUI
import MarketsDomain
import OrderbookDomain
import OrderbookPresentation
import DesignSystem

/// One card in the Referendums/Biggest-races carousels: volume, question, headline chance,
/// a lazily-loaded sparkline, and a Trade button — matching the web's card carousels.
struct MiniMarketCard: View {
    /// The event this card represents (its first market drives the chance/chart/trade).
    let event: Event
    /// Called with the market and side when Trade is tapped.
    let onTrade: (Market, Side) -> Void

    /// Supplies price-history data for the sparkline.
    @Environment(\.priceHistoryProvider) private var priceHistoryProvider
    /// The lazily-loaded sparkline points, empty until the fetch completes.
    @State private var points: [DesignSystem.PricePoint] = []

    /// The market driving this card's chance/chart/trade — the event's first market.
    private var market: Market? { event.markets.first }

    /// Whether Yes or No is currently favored (drives the headline color and chart tint).
    private var yesLeads: Bool { (market?.yesOutcome?.price ?? 0) >= 0.5 }

    var body: some View {
        DSCard {
            VStack(alignment: .leading, spacing: DSLayout.spacingSmall) {
                Text("\(MarketFormatting.compactUSD(event.volume)) Vol.")
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.textSecondary)
                Text(event.title.trimmingCharacters(in: .whitespaces))
                    .font(DSFont.headline)
                    .foregroundStyle(DSColor.textPrimary)
                    .lineLimit(3)
                if let market {
                    headline(for: market)
                }
                chartBody
                tradeButton
            }
        }
        .task(id: event.id) {
            guard let provider = priceHistoryProvider, let assetID = market?.yesOutcome?.id, !assetID.isEmpty else { return }
            let history = (try? await provider(assetID, .max)) ?? []
            points = history.map { DesignSystem.PricePoint(date: $0.date, price: NSDecimalNumber(decimal: $0.price).doubleValue) }
        }
    }

    /// "{X}% chance {yes/no}" in the leading side's color.
    private func headline(for market: Market) -> some View {
        let price = yesLeads ? market.yesOutcome?.price : market.noOutcome?.price
        let label = yesLeads ? (market.yesOutcome?.title ?? "yes") : (market.noOutcome?.title ?? "no")
        return Text("\(MarketFormatting.percent(price ?? 0)) chance \(label.lowercased())")
            .font(DSFont.subheadline.bold())
            .foregroundStyle(yesLeads ? DSColor.positive : DSColor.negative)
    }

    /// The sparkline, or an empty placeholder while it loads.
    @ViewBuilder
    private var chartBody: some View {
        if points.isEmpty {
            Color.clear.frame(height: 80)
        } else {
            PriceChart(data: points, color: yesLeads ? DSColor.positive : DSColor.negative)
                .frame(height: 80)
        }
    }

    /// Buy the currently-favored side.
    @ViewBuilder
    private var tradeButton: some View {
        if let market {
            Button {
                onTrade(market, yesLeads ? .yes : .no)
            } label: {
                Text("Trade")
                    .font(DSFont.subheadline.bold())
                    .foregroundStyle(DSColor.background)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DSLayout.spacingSmall)
                    .background(DSColor.textPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: DSLayout.chipRadius))
            }
            .buttonStyle(.plain)
        }
    }
}
