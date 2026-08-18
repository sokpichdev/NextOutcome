//
//  EsportsMatchDetailView.swift
//  NextOutcome
//
//  Created by Sok Pich on 10/08/2026.
//

import SwiftUI
import MarketsDomain
import DesignSystem

/// The Esports match detail screen, opened by tapping a match in the hub.
///
/// Mirrors web's match page: status line, title, the map-by-map scoreboard, a
/// Market/Livestream toggle, the two teams' win-probability chart, and the market sections.
/// It replaces the generic `EventDetailView` for esports matches, which was built around
/// Yes/No markets and rendered a team-named event with no prices and one giant "Other" section.
public struct EsportsMatchDetailView: View {
    /// The view model driving the screen.
    @State private var viewModel: EsportsMatchDetailViewModel
    /// Supplies chart price-history data.
    @Environment(\.priceHistoryProvider) private var priceHistoryProvider
    /// Factory for the social strip shown in the Discuss sheet.
    @Environment(\.socialStripFactory) private var socialStripFactory
    /// The (simulated) trade submitter for the trade sheet.
    @Environment(\.tradeSubmitter) private var tradeSubmitter
    /// The chart view model, created once a provider is available.
    @State private var chart: EventChartViewModel?
    /// The social strip view model, created once its factory is available.
    @State private var socialStrip: SocialStripViewModel?
    /// The selected chart timeframe.
    @State private var timeframe: ChartTimeframe = .max
    /// The Market/Livestream selection (0 = Market, 1 = Livestream).
    @State private var segmentSelection = 0
    /// The trade sheet's context, when open.
    @State private var tradeContext: TradeSheetContext?
    /// Whether the Rules bottom sheet is presented.
    @State private var showsRulesSheet = false
    /// Whether the Comments/Holders bottom sheet is presented.
    @State private var showsDiscussSheet = false

    /// Creates the screen.
    /// - Parameter viewModel: The match detail view model, built by the environment factory.
    public init(viewModel: EsportsMatchDetailViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSLayout.spacing) {
                statusLine
                Text(titleText)
                    .font(DSFont.title)
                    .foregroundStyle(DSColor.textPrimary)
                    .lineLimit(3)

                EsportsScoreboardView(model: viewModel.scoreboard)

                SegmentToggle(
                    segments: [
                        SegmentToggle.Segment(title: "Market"),
                        SegmentToggle.Segment(title: "Livestream", showsLiveDot: viewModel.isLive)
                    ],
                    selection: $segmentSelection
                )
                // `.contain` is required: the toggle is a plain HStack of buttons, so
                // without it the container is no accessibility element and the identifier
                // never reaches the tree (same trap as `EsportsStreamView`).
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("esports.detail.segment")

                if segmentSelection == 1 {
                    EsportsBroadcastPanel(
                        stream: viewModel.stream,
                        imageURL: viewModel.event.imageURL,
                        broadcastURL: viewModel.broadcastURL,
                        isLive: viewModel.isLive,
                        hasEnded: viewModel.hasEnded
                    )
                } else {
                    chartBlock
                    if let chart, case .loaded = chart.state {
                        TimeframePicker(selected: $timeframe)
                    }
                    marketSections
                }
            }
            .padding(.horizontal, DSLayout.margin)
            .padding(.top, DSLayout.spacing)
        }
        .background(DSColor.background)
        .detailToolbar(title: "Esports", actions: [.rules, .discuss, .bookmark, .link],
                       onAction: handleToolbarAction)
        // Market rows push a single market; the hub's stack doesn't register this itself.
        .navigationDestination(for: MarketNavigationTarget.self) { target in
            MarketDetailView(market: target.market, eventID: target.eventID)
        }
        .task {
            viewModel.start()
            await viewModel.refresh()
        }
        .onDisappear { viewModel.stop() }
        .task(id: viewModel.event.id) {
            guard let provider = priceHistoryProvider else { return }
            let vm = EventChartViewModel(event: viewModel.event, provider: provider,
                                         source: chartSource)
            chart = vm
            await vm.load()
            // Keep the chart current while the screen is open. Cancelled automatically on
            // disappear, which ends this loop.
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                guard !Task.isCancelled else { break }
                await vm.load()
            }
        }
        .task(id: viewModel.event.id) {
            guard let factory = socialStripFactory else { return }
            socialStrip = factory(eventID: viewModel.event.id,
                                  conditionId: viewModel.moneylineMarket?.conditionId,
                                  markets: viewModel.event.markets)
        }
        .onChange(of: timeframe) { _, new in chart?.timeframe = new }
        .onChange(of: segmentSelection) { _, new in
            // Probing a broadcast costs a page fetch, so it waits until the tab is opened.
            guard new == 1 else { return }
            Task { await viewModel.requestStream() }
        }
        .sheet(item: $tradeContext) { context in
            TradeSheet(viewModel: TradeSheetViewModel(market: context.market, side: context.side,
                                                      submitter: tradeSubmitter))
        }
        .sheet(isPresented: $showsRulesSheet) {
            ScrollView {
                RulesExpander(eventDescription: viewModel.event.description,
                              marketRules: marketRules, startsExpanded: true)
                    .padding(DSLayout.margin)
            }
            .presentationDetents([.medium, .large])
            .background(DSColor.background)
        }
        .sheet(isPresented: $showsDiscussSheet) {
            ScrollView {
                if let socialStrip {
                    SocialStripView(viewModel: socialStrip)
                        .padding(DSLayout.margin)
                }
            }
            .presentationDetents([.medium, .large])
            .background(DSColor.background)
        }
    }

    // MARK: - Header

    /// "● Map 3 of 3 · $88.3K Vol · Counter-Strike", matching web's status strip.
    private var statusLine: some View {
        HStack(spacing: DSLayout.spacingSmall) {
            if viewModel.isLive {
                Circle().fill(DSColor.negative).frame(width: 6, height: 6)
            }
            if let status = viewModel.statusText {
                Text(status)
                    .font(DSFont.caption.bold())
                    .foregroundStyle(viewModel.isLive ? DSColor.negative : DSColor.textSecondary)
            }
            Text("\(MarketFormatting.compactUSD(viewModel.event.volume)) Vol")
                .font(DSFont.caption)
                .foregroundStyle(DSColor.textSecondary)
                .rollingNumber(viewModel.event.volume)
            if let league = viewModel.league {
                Text(league.name)
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
        }
    }

    /// "Eternal Fire Academy vs Vitality Academy", falling back to the raw event title.
    private var titleText: String {
        guard let title = viewModel.info.title else { return viewModel.event.title }
        return "\(title.homeTeam) vs \(title.awayTeam)"
    }

    // MARK: - Market content

    /// What the chart draws: the two teams' win probability off the series moneyline, in
    /// their brand colours — the comparison web leads with, and the only one that means
    /// anything here. Falls back to the generic top-markets chart when there's no moneyline
    /// (an odd event shape), which still draws something now that it reads `primaryOutcome`.
    private var chartSource: EventChartViewModel.Source {
        guard let moneyline = viewModel.moneylineMarket else { return .topMarkets(limit: 4) }
        let info = viewModel.info
        let colors = [
            Color(hexString: info.home.colorHex) ?? OutcomePalette.color(0),
            Color(hexString: info.away.colorHex) ?? OutcomePalette.color(1)
        ]
        return .outcomes(of: moneyline, colors: colors)
    }

    /// The price chart area, switching on the chart view model's state.
    @ViewBuilder
    private var chartBlock: some View {
        if let chart {
            switch chart.state {
            case .loaded(let series):
                MultiSeriesChart(series: series).frame(height: 200)
            case .failed(let message):
                VStack(alignment: .leading, spacing: DSLayout.spacingSmall) {
                    Text(message).font(DSFont.caption).foregroundStyle(DSColor.textSecondary)
                    Button("Retry") { Task { await chart.retry() } }
                }
            case .idle, .loading:
                // Reserved height, same as the event detail chart — as a skeleton block so
                // the space reads as pending rather than as a gap.
                SkeletonView(.block(height: 200), placement: .inline)
            case .empty:
                EmptyView()
            }
        }
    }

    /// One `MarketGroupSection` per classified group.
    @ViewBuilder
    private var marketSections: some View {
        ForEach(viewModel.groups, id: \.group) { entry in
            MarketGroupSection(group: entry.group, markets: entry.markets,
                               eventID: viewModel.event.id, onSelect: presentTrade)
        }
    }

    /// The per-market resolution rules feeding the Rules sheet.
    private var marketRules: [RulesExpander.MarketRule] {
        viewModel.event.markets.compactMap { market in
            guard let rules = market.rules, !rules.isEmpty else { return nil }
            return RulesExpander.MarketRule(id: market.id,
                                            title: market.groupItemTitle ?? market.question,
                                            text: rules)
        }
    }

    // MARK: - Actions

    /// Routes a toolbar tap: Rules and Comments open their sheets; the rest are no-ops,
    /// matching `EventDetailView`.
    private func handleToolbarAction(_ action: DetailToolbarActions) {
        if action.contains(.rules) { showsRulesSheet = true }
        if action.contains(.discuss) { showsDiscussSheet = true }
    }

    /// Opens the mock trade sheet for a market/side.
    private func presentTrade(_ market: Market, _ side: Side) {
        tradeContext = TradeSheetContext(market: market, side: side)
    }
}
