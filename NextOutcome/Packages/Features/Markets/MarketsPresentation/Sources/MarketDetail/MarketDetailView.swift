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
    @Environment(\.marketHoldersFactory) private var marketHoldersFactory
    @Environment(\.dismiss) private var dismiss
    private let market: Market

    public init(market: Market) {
        self.market = market
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSLayout.spacingLarge) {
                DetailHeader(
                    title: .text(market.question, iconURL: market.imageURL),
                    actions: [.code, .bookmark, .link],
                    onBack: { dismiss() }
                )
                chanceHeader
                liveSection
                stats
                holdersSection
            }
            .padding(.horizontal, DSLayout.margin)
            .padding(.top, DSLayout.spacing)
        }
        .background(DSColor.background)
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
    }

    @ViewBuilder
    private var chanceHeader: some View {
        if let yes = market.yesOutcome {
            ChanceHeader(chanceFraction: yes.price, deltaPoints: nil,
                         leadingColor: DSColor.positive)
        }
    }

    /// Live orderbook + price chart, driven by the Yes token id. Rendered only
    /// when the App has injected a factory and the market has a CLOB token.
    @ViewBuilder
    private var liveSection: some View {
        // Resolved markets have no live order book — skip the live section entirely.
        if !market.isResolved,
           let factory = marketLiveFactory,
           let assetID = market.yesOutcome?.id, !assetID.isEmpty {
            MarketLiveView(viewModel: factory(assetID))
        }
    }

    /// Top holders, loaded via the injected factory when the market has a condition id.
    @ViewBuilder
    private var holdersSection: some View {
        if let factory = marketHoldersFactory, !market.conditionId.isEmpty {
            HoldersSection(viewModel: factory(market.conditionId))
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
