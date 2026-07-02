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

public struct EventDetailView: View {
    private let event: Event
    @Environment(\.dismiss) private var dismiss
    @Environment(\.priceHistoryProvider) private var priceHistoryProvider
    @State private var chart: EventChartViewModel?
    @State private var timeframe: ChartTimeframe = .max

    public init(event: Event) {
        self.event = event
    }

    private var breadcrumb: String {
        event.tags.first.map(\.label) ?? event.title
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSLayout.spacing) {
                DetailHeader(title: .breadcrumb(breadcrumb), actions: [.bookmark, .link],
                             onBack: { dismiss() })
                Text(event.title).font(DSFont.title).foregroundStyle(DSColor.textPrimary)
                if let chart, !chart.series.isEmpty {
                    MultiSeriesChart(series: chart.series).frame(height: 200)
                }
                TimeframePicker(selected: $timeframe)
                ForEach(event.markets) { market in
                    NavigationLink(value: market) {
                        MarketCard(market: market)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DSLayout.margin)
            .padding(.top, DSLayout.spacing)
        }
        .background(DSColor.background)
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .task {
            if chart == nil, let provider = priceHistoryProvider {
                let vm = EventChartViewModel(event: event, provider: provider)
                chart = vm
                await vm.load()
            }
        }
        .onChange(of: timeframe) { _, new in chart?.timeframe = new }
    }
}
