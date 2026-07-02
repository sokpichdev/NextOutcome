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

/// Tracks how far the hero region (breadcrumb → header → chart) has scrolled past the top
/// of the scroll view, so `EventDetailView` can decide when to overlay `StickyEventHeader`.
private struct HeroScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = .greatestFiniteMagnitude
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = min(value, nextValue())
    }
}

public struct EventDetailView: View {
    private let event: Event
    private let onSelect: (Market, Side) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.priceHistoryProvider) private var priceHistoryProvider
    @State private var chart: EventChartViewModel?
    @State private var timeframe: ChartTimeframe = .max
    @State private var segmentSelection = 0
    @State private var showsStickyHeader = false

    /// `onSelect` is the trade-sheet hook Task 8 wires up; no-op until then.
    public init(event: Event, onSelect: @escaping (Market, Side) -> Void = { _, _ in }) {
        self.event = event
        self.onSelect = onSelect
    }

    private var breadcrumb: String {
        event.tags.first.map(\.label) ?? event.title
    }

    private var groups: [(group: MarketGroup, markets: [Market])] {
        MarketGroupClassifier.groups(for: event.markets)
    }

    private var marketRules: [RulesExpander.MarketRule] {
        event.markets.compactMap { market in
            guard let rules = market.rules, !rules.isEmpty else { return nil }
            return RulesExpander.MarketRule(id: market.id, title: market.groupItemTitle ?? market.question, text: rules)
        }
    }

    private var showsLive: Bool {
        LiveTabGate.showsLive(gameStartTime: event.gameStartTime, hasTeams: event.hasTeams,
                               isResolved: event.isResolved, now: Date())
    }

    private var topMarket: Market? { event.markets.first }

    public var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(alignment: .leading, spacing: DSLayout.spacing) {
                    DetailHeader(title: .breadcrumb(breadcrumb), actions: [.bookmark, .link],
                                 onBack: { dismiss() })
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
                        liveTabPlaceholder
                    } else {
                        chartBlock
                            .background(heroOffsetReader)
                        if let chart, case .loaded = chart.state {
                            TimeframePicker(selected: $timeframe)
                        }
                        marketGroupSections
                    }

                    RulesExpander(eventDescription: event.description, marketRules: marketRules)
                    socialStripPlaceholder
                }
                .padding(.horizontal, DSLayout.margin)
                .padding(.top, DSLayout.spacing)
            }
            .coordinateSpace(name: "eventDetailScroll")
            .background(DSColor.background)
            #if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
            #endif
            .task(id: event.id) {
                guard let provider = priceHistoryProvider else { return }
                let vm = EventChartViewModel(event: event, provider: provider)
                chart = vm
                await vm.load()
            }
            .onChange(of: timeframe) { _, new in chart?.timeframe = new }
            .onPreferenceChange(HeroScrollOffsetKey.self) { offset in
                showsStickyHeader = offset < 0
            }

            if showsStickyHeader {
                StickyEventHeader(leftAbbrev: stickyLeftAbbrev, rightAbbrev: stickyRightAbbrev,
                                   chanceText: stickyChanceText) {
                    if let topMarket { onSelect(topMarket, .yes) }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.15), value: showsStickyHeader)
    }

    /// Invisible marker at the bottom of the chart block; once it scrolls above the
    /// scroll view's top edge, the sticky header takes over.
    private var heroOffsetReader: some View {
        GeometryReader { geo in
            Color.clear.preference(
                key: HeroScrollOffsetKey.self,
                value: geo.frame(in: .named("eventDetailScroll")).maxY
            )
        }
    }

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
            case .idle, .loading, .empty:
                EmptyView()
            }
        }
    }

    @ViewBuilder
    private var marketGroupSections: some View {
        ForEach(groups, id: \.group) { entry in
            MarketGroupSection(group: entry.group, markets: entry.markets, onSelect: onSelect)
        }
    }

    private var liveTabPlaceholder: some View {
        VStack(alignment: .leading, spacing: DSLayout.spacingSmall) {
            Text("Live stats").font(DSFont.subheadline.bold()).foregroundStyle(DSColor.textPrimary)
            Text("Live match stats are coming soon.").font(DSFont.caption).foregroundStyle(DSColor.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, DSLayout.spacingLarge)
    }

    private var socialStripPlaceholder: some View {
        VStack(alignment: .leading, spacing: DSLayout.spacingSmall) {
            Text("Comments").font(DSFont.subheadline.bold()).foregroundStyle(DSColor.textPrimary)
            Text("Comments are coming soon.").font(DSFont.caption).foregroundStyle(DSColor.textSecondary)
        }
    }

    private var stickyChanceText: String {
        guard let yes = topMarket?.yesOutcome else { return "" }
        return MarketFormatting.percent(yes.price)
    }

    private var stickyLeftAbbrev: String {
        abbreviate(topMarket?.groupItemTitle ?? topMarket?.yesOutcome?.title ?? "Yes")
    }

    private var stickyRightAbbrev: String {
        if event.hasTeams, let second = event.markets.dropFirst().first?.groupItemTitle {
            return abbreviate(second)
        }
        return abbreviate(topMarket?.noOutcome?.title ?? "No")
    }

    private func abbreviate(_ s: String) -> String {
        String(s.prefix(3)).uppercased()
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
