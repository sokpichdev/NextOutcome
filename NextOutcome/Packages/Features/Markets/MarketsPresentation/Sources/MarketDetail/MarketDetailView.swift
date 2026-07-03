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

/// Pushed as a `NavigationLink(value:)` target instead of a bare `Market` wherever the
/// pushing view has a parent `Event` in scope, so `MarketDetailView` can thread the real
/// event id down to `SocialStripView` (Gamma scopes `/comments` per-event, not per-market).
public struct MarketNavigationTarget: Hashable {
    public let market: Market
    public let eventID: String

    public init(market: Market, eventID: String) {
        self.market = market
        self.eventID = eventID
    }
}

public struct MarketDetailView: View {
    @Environment(\.marketLiveFactory) private var marketLiveFactory
    @Environment(\.orderbookFactory) private var orderbookFactory
    @Environment(\.socialStripFactory) private var socialStripFactory
    @Environment(\.dismiss) private var dismiss
    @State private var portfolioSegment = 0
    private let market: Market
    /// The parent event's id, used to scope the Comments strip. `nil` when this screen was
    /// reached from a flow with no event context (Search results are flat markets with no
    /// parent event attached) — the comments strip is hidden rather than sending a wrong id.
    private let eventID: String?

    public init(market: Market, eventID: String? = nil) {
        self.market = market
        self.eventID = eventID
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
                orderbookSection
                stats
                portfolioSection
                socialStripSection
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
        } else {
            Text("Outcomes unavailable")
                .font(DSFont.subheadline)
                .foregroundStyle(DSColor.textSecondary)
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

    /// Expandable live order book, driven by the Yes token id. Rendered below the
    /// price chart, independently of `MarketLiveView`'s own view model.
    @ViewBuilder
    private var orderbookSection: some View {
        if !market.isResolved,
           let factory = orderbookFactory,
           let assetID = market.yesOutcome?.id, !assetID.isEmpty {
            OrderbookView(viewModel: factory(assetID))
        }
    }

    /// Positions / Open Orders / History — static empty states until sub-project D
    /// wires real portfolio data into Market Detail.
    private var portfolioSection: some View {
        DSCard {
            VStack(alignment: .leading, spacing: DSLayout.spacing) {
                SegmentToggle(
                    segments: [
                        .init(title: "Positions"),
                        .init(title: "Open Orders"),
                        .init(title: "History")
                    ],
                    selection: $portfolioSegment
                )
                portfolioEmptyState
            }
        }
    }

    private var portfolioEmptyState: some View {
        VStack(alignment: .leading, spacing: DSLayout.spacingSmall) {
            Text(portfolioEmptyTitle)
                .font(DSFont.subheadline.bold())
                .foregroundStyle(DSColor.textPrimary)
            Text("Your \(portfolioEmptyTitle.lowercased()) appear here once funding arrives")
                .font(DSFont.caption)
                .foregroundStyle(DSColor.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, DSLayout.spacingLarge)
    }

    private var portfolioEmptyTitle: String {
        switch portfolioSegment {
        case 1: return "Open orders"
        case 2: return "History"
        default: return "Positions"
        }
    }

    /// Comments · Top holders strip, reused from Task 5's Event Detail. Requires the real
    /// parent event id (Gamma scopes `/comments` per-event); hidden entirely when this
    /// screen has no event in scope rather than fetching comments under the wrong id.
    @ViewBuilder
    private var socialStripSection: some View {
        if let factory = socialStripFactory, let eventID {
            SocialStripView(viewModel: factory(eventID: eventID, conditionId: market.conditionId))
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
