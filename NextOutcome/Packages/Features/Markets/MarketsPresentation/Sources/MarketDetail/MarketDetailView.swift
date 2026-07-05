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
    /// The market to open.
    public let market: Market
    /// The parent event's id, threaded down so comments can be scoped correctly.
    public let eventID: String

    /// Creates a navigation target.
    /// - Parameters:
    ///   - market: The market to open.
    ///   - eventID: The parent event's id.
    public init(market: Market, eventID: String) {
        self.market = market
        self.eventID = eventID
    }
}

/// The market detail screen: chance header, Yes/No trade buttons, live chart and order book,
/// a mock portfolio section, market stats, and the comments/holders social strip.
public struct MarketDetailView: View {
    /// Factory for the live price chart view model.
    @Environment(\.marketLiveFactory) private var marketLiveFactory
    /// Factory for the order book view model.
    @Environment(\.orderbookFactory) private var orderbookFactory
    /// Factory for the social strip (comments/holders) view model.
    @Environment(\.socialStripFactory) private var socialStripFactory
    /// The (simulated) trade submitter for the trade sheet.
    @Environment(\.tradeSubmitter) private var tradeSubmitter
    /// The selected segment of the mock portfolio section.
    @State private var portfolioSegment = 0
    /// Task 8's mock trade sheet, opened from the Yes/No buttons next to the order book.
    @State private var tradeContext: TradeSheetContext?
    /// The market being displayed.
    private let market: Market
    /// The parent event's id, used to scope the Comments strip. `nil` when this screen was
    /// reached from a flow with no event context (Search results are flat markets with no
    /// parent event attached) — the comments strip is hidden rather than sending a wrong id.
    private let eventID: String?

    /// Creates the view.
    /// - Parameters:
    ///   - market: The market to display.
    ///   - eventID: The parent event id (for comments); `nil` hides the comments strip.
    public init(market: Market, eventID: String? = nil) {
        self.market = market
        self.eventID = eventID
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSLayout.spacingLarge) {
                chanceHeader
                tradeRow
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
        .detailToolbar(title: market.question, iconURL: market.imageURL, actions: [.code, .bookmark, .link])
        .sheet(item: $tradeContext) { context in
            TradeSheet(viewModel: TradeSheetViewModel(market: context.market, side: context.side, submitter: tradeSubmitter))
        }
    }

    /// Yes/No entry into the mock trade sheet — Task 8's hook next to the order book.
    @ViewBuilder
    private var tradeRow: some View {
        if let yes = market.yesOutcome, let no = market.noOutcome {
            HStack(spacing: DSLayout.spacingSmall) {
                PriceButton(title: yes.title, price: cents(yes.price), style: .yes) {
                    tradeContext = TradeSheetContext(market: market, side: .yes)
                }
                PriceButton(title: no.title, price: cents(no.price), style: .no) {
                    tradeContext = TradeSheetContext(market: market, side: .no)
                }
            }
        }
    }

    /// Formats a 0…1 price as a cent label (reusing the percent formatter's number).
    private func cents(_ price: Decimal) -> String {
        MarketFormatting.percent(price).replacingOccurrences(of: "%", with: "¢")
    }

    /// The big "% chance" header, or a fallback when the market has no outcomes.
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
    /// The mock Positions/Open Orders/History section with empty states (real data lands
    /// with funding).
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

    /// The empty-state copy for the selected portfolio segment.
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

    /// The title for the currently-selected portfolio segment.
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

    /// The market stats card: volume, liquidity, and status/countdown.
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

    /// A single label/value row in the stats card.
    /// - Parameters:
    ///   - label: The row's label.
    ///   - value: The row's formatted value.
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
