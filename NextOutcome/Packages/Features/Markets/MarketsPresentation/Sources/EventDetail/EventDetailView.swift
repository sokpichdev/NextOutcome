//
//  EventDetailView.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import SwiftUI
import MarketsDomain
import DesignSystem
import OrderbookPresentation
import LiveStatsPresentation

/// Pure helper for deriving the sticky-header's paired team abbreviations from an event's
/// moneyline markets, so pairing survives non-alternating market ordering.
enum StickyHeaderAbbreviations {
    /// Derives the left/right abbreviations from the first two markets in the event's
    /// moneyline group (`MarketGroupClassifier`). Returns `nil` when there's no moneyline
    /// group, it has fewer than two markets, or either market's `groupItemTitle` is missing
    /// or empty — callers should fall back to their own chain in that case.
    static func stickyAbbreviations(for markets: [Market]) -> (left: String, right: String)? {
        guard let moneyline = MarketGroupClassifier.groups(for: markets)
            .first(where: { $0.group == .moneyline })?.markets,
            moneyline.count >= 2,
            let leftTitle = moneyline[0].groupItemTitle.flatMap({ $0.isEmpty ? nil : $0 }),
            let rightTitle = moneyline[1].groupItemTitle.flatMap({ $0.isEmpty ? nil : $0 })
        else { return nil }
        return (left: abbreviate(leftTitle), right: abbreviate(rightTitle))
    }

    /// Shortens a name to a 3-letter uppercase abbreviation (e.g. "Argentina" → "ARG").
    static func abbreviate(_ s: String) -> String {
        String(s.prefix(3)).uppercased()
    }
}

/// Tracks how far the hero region (breadcrumb → header → chart) has scrolled past the top
/// of the scroll view, so `EventDetailView` can decide when to overlay `StickyEventHeader`.
private struct HeroScrollOffsetKey: PreferenceKey {
    /// The default (nothing measured yet).
    static var defaultValue: CGFloat = .greatestFiniteMagnitude
    /// Combines child values by taking the minimum offset seen.
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = min(value, nextValue())
    }
}

/// The event detail screen: header, an optional Market/Live segment toggle, a multi-series
/// price chart, grouped market sections, a rules expander, and the social strip. Overlays a
/// compact sticky header once the hero region scrolls off-screen.
public struct EventDetailView: View {
    /// The event being displayed.
    private let event: Event
    /// Callback fired when a price button is tapped (also opens the trade sheet).
    private let onSelect: (Market, Side) -> Void
    /// Supplies chart price-history data.
    @Environment(\.priceHistoryProvider) private var priceHistoryProvider
    /// Factory for the social strip view model.
    @Environment(\.socialStripFactory) private var socialStripFactory
    /// The (simulated) trade submitter for the trade sheet.
    @Environment(\.tradeSubmitter) private var tradeSubmitter
    /// The chart view model, created once a provider is available.
    @State private var chart: EventChartViewModel?
    /// The social strip view model, created once its factory is available.
    @State private var socialStrip: SocialStripViewModel?
    /// The selected chart timeframe.
    @State private var timeframe: ChartTimeframe = .max
    /// The Market/Live segment selection (0 = Market, 1 = Live).
    @State private var segmentSelection = 0
    /// Whether the compact sticky header is currently overlaid.
    @State private var showsStickyHeader = false
    /// Task 8's mock trade sheet, opened from `onSelect`/the sticky-header Trade button.
    @State private var tradeContext: TradeSheetContext?
    /// Whether the Rules bottom sheet is presented.
    @State private var showsRulesSheet = false
    /// Whether the Comments/Top Holders/Positions/Activity bottom sheet is presented.
    @State private var showsDiscussSheet = false

    /// `onSelect` is the trade-sheet hook Task 8 wires up; no-op until then.
    public init(event: Event, onSelect: @escaping (Market, Side) -> Void = { _, _ in }) {
        self.event = event
        self.onSelect = onSelect
    }

    /// The breadcrumb label above the title: the first tag, or the title as a fallback.
    private var breadcrumb: String {
        event.tags.first.map(\.label) ?? event.title
    }

    /// The event's markets grouped into live-site sections via `MarketGroupClassifier`.
    private var groups: [(group: MarketGroup, markets: [Market])] {
        MarketGroupClassifier.groups(for: event.markets)
    }

    /// The per-market resolution rules to feed the `RulesExpander` (markets without rules
    /// are skipped).
    private var marketRules: [RulesExpander.MarketRule] {
        event.markets.compactMap { market in
            guard let rules = market.rules, !rules.isEmpty else { return nil }
            return RulesExpander.MarketRule(id: market.id, title: market.groupItemTitle ?? market.question, text: rules)
        }
    }

    /// Whether the Live segment should be offered (see `LiveTabGate`).
    private var showsLive: Bool {
        LiveTabGate.showsLive(gameStartTime: event.gameStartTime, hasTeams: event.hasTeams,
                               isResolved: event.isResolved, now: Date())
    }

    /// The event's primary market (used for the sticky header and trade shortcut).
    private var topMarket: Market? { event.markets.first }

    public var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(alignment: .leading, spacing: DSLayout.spacing) {
                    header

                    if showsLive {
                        SegmentToggle(
                            segments: [
                                SegmentToggle.Segment(title: "Market"),
                                SegmentToggle.Segment(title: "Live", showsLiveDot: true)
                            ],
                            selection: $segmentSelection
                        )
                    }

                    if showsLive && segmentSelection == 1 {
                        LiveTabView(gameID: event.id)
                    } else {
                        chartBlock
                            .background(heroOffsetReader)
                        if let chart, case .loaded = chart.state {
                            TimeframePicker(selected: $timeframe)
                        }
                        marketGroupSections
                    }
                }
                .padding(.horizontal, DSLayout.margin)
                .padding(.top, DSLayout.spacing)
            }
            .coordinateSpace(name: "eventDetailScroll")
            .background(DSColor.background)
            .detailToolbar(title: breadcrumb, actions: [.rules, .discuss, .bookmark, .link], onAction: handleHeaderAction)
            .task(id: event.id) {
                guard let provider = priceHistoryProvider else { return }
                let vm = EventChartViewModel(event: event, provider: provider)
                chart = vm
                await vm.load()
                // Keep the chart/legend percentages current while the screen is open.
                // The `.task` is cancelled automatically on disappear or when `event.id`
                // changes, which ends this loop.
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 30_000_000_000)
                    guard !Task.isCancelled else { break }
                    await vm.load()
                }
            }
            .task(id: event.id) {
                guard let factory = socialStripFactory else { return }
                socialStrip = factory(eventID: event.id, conditionId: topMarket?.conditionId, markets: event.markets)
            }
            .onChange(of: timeframe) { _, new in chart?.timeframe = new }
            .onPreferenceChange(HeroScrollOffsetKey.self) { offset in
                showsStickyHeader = offset < 0
            }

            if showsStickyHeader {
                StickyEventHeader(leftAbbrev: stickyLeftAbbrev, rightAbbrev: stickyRightAbbrev,
                                   chanceText: stickyChanceText) {
                    if let topMarket { presentTrade(topMarket, .yes) }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.15), value: showsStickyHeader)
        .sheet(item: $tradeContext) { context in
            TradeSheet(viewModel: TradeSheetViewModel(market: context.market, side: context.side, submitter: tradeSubmitter))
        }
        .sheet(isPresented: $showsRulesSheet) {
            ScrollView {
                RulesExpander(eventDescription: event.description, marketRules: marketRules, startsExpanded: true)
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

    /// Routes a toolbar trailing-action tap: Rules/Comments open their bottom sheets;
    /// bookmark/link/embed are no-ops for now (unchanged from before).
    private func handleHeaderAction(_ action: DetailToolbarActions) {
        if action.contains(.rules) { showsRulesSheet = true }
        if action.contains(.discuss) { showsDiscussSheet = true }
    }

    /// Opens the mock trade sheet for `market`/`side` and still forwards to the
    /// caller-supplied `onSelect` hook, so any host that overrides it (e.g. tests) keeps
    /// seeing selection events.
    private func presentTrade(_ market: Market, _ side: Side) {
        tradeContext = TradeSheetContext(market: market, side: side)
        onSelect(market, side)
    }

    /// Invisible marker at the bottom of the chart block; once it scrolls above the
    /// scroll view's top edge, the sticky header takes over.
    /// The invisible marker below the chart whose position drives `showsStickyHeader`.
    private var heroOffsetReader: some View {
        GeometryReader { geo in
            Color.clear.preference(
                key: HeroScrollOffsetKey.self,
                value: geo.frame(in: .named("eventDetailScroll")).maxY
            )
        }
    }

    /// The event title plus an optional kickoff countdown.
    @ViewBuilder
    private var header: some View {
        VStack(alignment: .leading, spacing: DSLayout.spacingSmall) {
            Text(event.title).font(DSFont.title).foregroundStyle(DSColor.textPrimary)
            if let gameStartTime = event.gameStartTime, let countdown = MarketFormatting.countdown(to: gameStartTime) {
                HStack(spacing: DSLayout.spacingXSmall) {
                    Image(systemName: "clock")
                    Text(countdown)
                }
                .font(DSFont.caption)
                .foregroundStyle(DSColor.textSecondary)
            }
        }
    }

    /// The price chart area, switching on the chart view model's state (loaded/error/loading/
    /// empty). A cleared 200pt block is reserved during load so the sticky-header marker
    /// doesn't jump.
    @ViewBuilder
    private var chartBlock: some View {
        if let chart {
            switch chart.state {
            case .loaded(let series):
                MultiSeriesChart(series: series).frame(height: 200)
            case .failed(let message):
                VStack(alignment: .leading, spacing: 8) {
                    Text(message).font(DSFont.caption).foregroundStyle(DSColor.textSecondary)
                    Button("Retry") { Task { await chart.retry() } }
                }
            case .idle, .loading:
                // Reserve the same height as the loaded chart so the `heroOffsetReader`
                // marker (attached below `chartBlock`) stays put during the load
                // transition instead of jumping once the chart lays out (Finding 1).
                Color.clear.frame(height: 200)
            case .empty:
                EmptyView()
            }
        }
    }

    /// One `MarketGroupSection` per classified group.
    @ViewBuilder
    private var marketGroupSections: some View {
        ForEach(groups, id: \.group) { entry in
            MarketGroupSection(group: entry.group, markets: entry.markets, eventID: event.id, onSelect: presentTrade)
        }
    }

    /// The chance percentage shown in the sticky header (from the top market's Yes price).
    private var stickyChanceText: String {
        guard let yes = topMarket?.yesOutcome else { return "" }
        return MarketFormatting.percent(yes.price)
    }

    /// The paired team abbreviations from the moneyline group, if derivable.
    private var stickyMoneylineAbbrevs: (left: String, right: String)? {
        StickyHeaderAbbreviations.stickyAbbreviations(for: event.markets)
    }

    /// The left abbreviation for the sticky header, with a fallback chain when there's no
    /// moneyline pairing.
    private var stickyLeftAbbrev: String {
        if let pair = stickyMoneylineAbbrevs { return pair.left }
        let groupTitle = topMarket?.groupItemTitle.flatMap { $0.isEmpty ? nil : $0 }
        let yesTitle = topMarket?.yesOutcome?.title
        let yesTitleOrNil = (yesTitle?.isEmpty ?? true) ? nil : yesTitle
        let fallback = groupTitle ?? yesTitleOrNil ?? "Yes"
        return abbreviate(fallback)
    }

    /// The right abbreviation for the sticky header, with a fallback chain when there's no
    /// moneyline pairing.
    private var stickyRightAbbrev: String {
        if let pair = stickyMoneylineAbbrevs { return pair.right }
        if event.hasTeams,
           let second = event.markets.dropFirst().first?.groupItemTitle.flatMap({ $0.isEmpty ? nil : $0 }) {
            return abbreviate(second)
        }
        let noTitle = topMarket?.noOutcome?.title
        let noTitleOrNil = (noTitle?.isEmpty ?? true) ? nil : noTitle
        let fallback = noTitleOrNil ?? "No"
        return abbreviate(fallback)
    }

    /// Local shorthand for `StickyHeaderAbbreviations.abbreviate`.
    private func abbreviate(_ s: String) -> String {
        StickyHeaderAbbreviations.abbreviate(s)
    }
}

#if DEBUG
private func _mkt(_ groupTitle: String, _ yes: Double, sportsType: String? = nil, question: String? = nil) -> Market {
    Market(id: groupTitle, question: question ?? "\(groupTitle) moneyline", slug: groupTitle,
           outcomes: [Outcome(id: "y", title: "Yes", price: Decimal(yes)),
                      Outcome(id: "n", title: "No", price: Decimal(1 - yes))],
           volume: 0, liquidity: 0, endDate: nil, isResolved: false, imageURL: nil,
           sportsMarketType: sportsType, groupItemTitle: sportsType != nil ? groupTitle : nil,
           rules: "If \(groupTitle) wins, this market resolves \"Yes\". Otherwise \"No\".")
}

#Preview("Event detail — sports, in progress") {
    NavigationStack {
        EventDetailView(event: Event(
            id: "e1", title: "Argentina – Cabo Verde",
            slug: "arg-cvi", markets: [
                _mkt("Argentina", 0.86, sportsType: "moneyline"),
                _mkt("Cabo Verde", 0.043, sportsType: "moneyline"),
                _mkt("Argentina", 0.39, sportsType: "spreads", question: "Argentina -2.5"),
                _mkt("Cabo Verde", 0.62, sportsType: "spreads", question: "Cabo Verde +2.5")
            ], volume: 3_150_000, imageURL: nil,
            tags: [Tag(id: "wc", label: "World Cup", slug: "world-cup")],
            gameStartTime: .distantPast,
            description: "This event resolves based on the official FIFA World Cup bracket."
        ))
    }
}

#Preview("Event detail — binary market") {
    NavigationStack {
        EventDetailView(event: Event(
            id: "e2", title: "Will BTC hit $150k in 2026?",
            slug: "btc-150k", markets: [_mkt("Yes", 0.31)],
            volume: 820_000, imageURL: nil
        ))
    }
}
#endif
