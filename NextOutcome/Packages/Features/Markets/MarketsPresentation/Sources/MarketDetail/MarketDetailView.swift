//
//  MarketDetailView.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import SwiftUI
import MarketsDomain
import DesignSystem
import OrderbookPresentation

public struct MarketDetailView: View {
    @Environment(\.marketLiveFactory) private var marketLiveFactory
    private let market: Market

    public init(market: Market) {
        self.market = market
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSLayout.spacingLarge) {
                priceHeader
                liveSection
                stats
            }
            .padding(.horizontal, DSLayout.margin)
            .padding(.top, DSLayout.spacing)
        }
        .background(DSColor.background)
        .navigationTitle(market.question)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    /// Live orderbook + price chart, driven by the Yes token id. Rendered only
    /// when the App has injected a factory and the market has a CLOB token.
    @ViewBuilder
    private var liveSection: some View {
        if let factory = marketLiveFactory, let assetID = market.yesOutcome?.id, !assetID.isEmpty {
            MarketLiveView(viewModel: factory(assetID))
        }
    }

    @ViewBuilder
    private var priceHeader: some View {
        if let yes = market.yesOutcome {
            DSCard(highlighted: true) {
                VStack(alignment: .leading, spacing: DSLayout.spacing) {
                    HStack(spacing: DSLayout.spacingLarge) {
                        priceColumn("Yes", MarketFormatting.percent(yes.price), DSColor.positive)
                        priceColumn("No", MarketFormatting.percent(yes.complement), DSColor.negative)
                        Spacer()
                    }
                    ProbabilityBar(yesFraction: MarketFormatting.fraction(yes.price))
                }
            }
        } else {
            DSCard {
                Text("Outcomes unavailable")
                    .font(DSFont.subheadline)
                    .foregroundStyle(DSColor.textSecondary)
            }
        }
    }

    private func priceColumn(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(DSFont.caption)
                .foregroundStyle(DSColor.textSecondary)
            Text(value)
                .font(DSFont.price)
                .foregroundStyle(color)
        }
    }

    private var stats: some View {
        DSCard {
            VStack(alignment: .leading, spacing: DSLayout.spacing) {
                statRow("Volume", MarketFormatting.compactUSD(market.volume))
                statRow("Liquidity", MarketFormatting.compactUSD(market.liquidity))
                if let countdown = MarketFormatting.countdown(to: market.endDate) {
                    statRow("Status", countdown)
                }
            }
        }
    }

    private func statRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(DSFont.subheadline)
                .foregroundStyle(DSColor.textSecondary)
            Spacer()
            Text(value)
                .font(DSFont.subheadline)
                .foregroundStyle(DSColor.textPrimary)
        }
    }
}
