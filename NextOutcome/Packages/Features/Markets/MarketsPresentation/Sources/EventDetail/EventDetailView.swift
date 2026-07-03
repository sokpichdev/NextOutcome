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

    static func abbreviate(_ s: String) -> String {
        String(s.prefix(3)).uppercased()
    }
}

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
    @Environment(\.socialStripFactory) private var socialStripFactory
    @State private var chart: EventChartViewModel?
    @State private var socialStrip: SocialStripViewModel?
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
                    socialStripSection
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
            .task(id: event.id) {
                guard let factory = socialStripFactory else { return }
                socialStrip = factory(eventID: event.id, conditionId: topMarket?.conditionId)
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

    @ViewBuilder
    private var marketGroupSections: some View {
        ForEach(groups, id: \.group) { entry in
            MarketGroupSection(group: entry.group, markets: entry.markets, eventID: event.id, onSelect: onSelect)
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

    @ViewBuilder
    private var socialStripSection: some View {
        if let socialStrip {
            SocialStripView(viewModel: socialStrip)
        }
    }

    private var stickyChanceText: String {
        guard let yes = topMarket?.yesOutcome else { return "" }
        return MarketFormatting.percent(yes.price)
    }

    private var stickyMoneylineAbbrevs: (left: String, right: String)? {
        StickyHeaderAbbreviations.stickyAbbreviations(for: event.markets)
    }

    private var stickyLeftAbbrev: String {
        if let pair = stickyMoneylineAbbrevs { return pair.left }
        let groupTitle = topMarket?.groupItemTitle.flatMap { $0.isEmpty ? nil : $0 }
        let yesTitle = topMarket?.yesOutcome?.title
        let yesTitleOrNil = (yesTitle?.isEmpty ?? true) ? nil : yesTitle
        let fallback = groupTitle ?? yesTitleOrNil ?? "Yes"
        return abbreviate(fallback)
    }

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
