//
//  MoversDetailView.swift
//  NextOutcome
//
//  Created by Sok Pich on 05/07/2026.
//

import SwiftUI
import MarketsDomain
import DesignSystem
import SharedDomain

/// The bespoke Breaking movers detail: the mover's headline chance + 24h delta, a multi-series
/// chart of the parent event's sibling outcomes with a timeframe picker and volume line, and a
/// Buy Yes / Buy No trade row. Reuses `EventChartViewModel` / `MultiSeriesChart` for the chart.
public struct MoversDetailView: View {
    /// The view model, which fetches the parent event and builds the chart.
    @State private var viewModel: MoversDetailViewModel
    /// The (simulated) trade submitter for the Buy Yes/No sheet.
    @Environment(\.tradeSubmitter) private var tradeSubmitter
    /// The context that presents the mock trade sheet, when a Buy button is tapped.
    @State private var tradeContext: TradeSheetContext?

    /// Creates the view.
    /// - Parameter viewModel: The movers-detail view model (built by the factory).
    public init(viewModel: MoversDetailViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSLayout.spacingLarge) {
                header
                chartSection
                tradeRow
            }
            .padding(.horizontal, DSLayout.margin)
            .padding(.top, DSLayout.spacing)
        }
        .background(DSColor.background)
        .detailToolbar(title: viewModel.mover.eventTitle, iconURL: viewModel.mover.imageURL, actions: [.bookmark, .link])
        .sheet(item: $tradeContext) { context in
            TradeSheet(viewModel: TradeSheetViewModel(market: context.market, side: context.side, submitter: tradeSubmitter))
        }
        .task { await viewModel.load() }
    }

    /// The mover headline: category breadcrumb, question, big chance, and coloured 24h delta.
    private var header: some View {
        VStack(alignment: .leading, spacing: DSLayout.spacingXSmall) {
            if !viewModel.categoryBreadcrumb.isEmpty {
                Text(viewModel.categoryBreadcrumb)
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.textSecondary)
            }
            Text(viewModel.mover.question)
                .font(DSFont.headline)
                .foregroundStyle(DSColor.textPrimary)
            HStack(alignment: .firstTextBaseline, spacing: DSLayout.spacingSmall) {
                Text(MarketFormatting.percent(viewModel.mover.probability))
                    .font(DSFont.largeTitle)
                    .foregroundStyle(DSColor.textPrimary)
                delta
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The 24h delta chip beside the headline chance.
    private var delta: some View {
        let points = Int((NSDecimalNumber(decimal: viewModel.mover.magnitude).doubleValue * 100).rounded())
        let color = viewModel.mover.isUp ? DSColor.positive : DSColor.negative
        return HStack(spacing: 2) {
            Image(systemName: viewModel.mover.isUp ? "arrow.up.right" : "arrow.down.right")
            Text("\(points)%")
        }
        .font(DSFont.subheadline.bold())
        .foregroundStyle(color)
    }

    /// The chart section, or a loading/error placeholder while the event/chart loads.
    @ViewBuilder
    private var chartSection: some View {
        if let chart = viewModel.chart {
            MoversChartSection(chart: chart, volumeText: volumeText)
        } else if let message = viewModel.errorMessage {
            VStack(spacing: DSLayout.spacingSmall) {
                Text(message).font(DSFont.subheadline).foregroundStyle(DSColor.textSecondary)
                Button("Retry") { Task { await viewModel.load() } }.tint(DSColor.accent)
            }
            .frame(maxWidth: .infinity, minHeight: 220)
        } else {
            StateView(.loading).frame(height: 220)
        }
    }

    /// "🏆 $358K Vol." line built from the parent event's total volume.
    private var volumeText: String {
        let volume = viewModel.event?.volume ?? viewModel.mover.volume24h
        return "\(MarketFormatting.compactUSD(volume)) Vol."
    }

    /// Buy Yes / Buy No entry into the mock trade sheet for the mover's market.
    @ViewBuilder
    private var tradeRow: some View {
        if let market = viewModel.primaryMarket, let yes = market.yesOutcome, let no = market.noOutcome {
            HStack(spacing: DSLayout.spacingSmall) {
                PriceButton(title: "Buy \(yes.title)", price: cents(yes.price), style: .yes) {
                    tradeContext = TradeSheetContext(market: market, side: .yes)
                }
                PriceButton(title: "Buy \(no.title)", price: cents(no.price), style: .no) {
                    tradeContext = TradeSheetContext(market: market, side: .no)
                }
            }
        }
    }

    /// Formats a 0…1 price as a cent label.
    private func cents(_ price: Decimal) -> String {
        MarketFormatting.percent(price).replacingOccurrences(of: "%", with: "¢")
    }
}

/// The chart block: a multi-series line chart of the event's outcomes, a volume line, and a
/// timeframe picker bound to the chart view model. Split out so it can `@Bindable` the chart.
private struct MoversChartSection: View {
    /// The chart view model, bindable so the timeframe picker can drive reloads.
    @Bindable var chart: EventChartViewModel
    /// The formatted volume line shown under the chart.
    let volumeText: String

    var body: some View {
        VStack(alignment: .leading, spacing: DSLayout.spacing) {
            chartBody
            HStack {
                Label(volumeText, systemImage: "trophy")
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.textSecondary)
                Spacer()
                TimeframePicker(selected: $chart.timeframe)
            }
        }
    }

    /// The chart itself, switching on the chart view model's load state.
    @ViewBuilder
    private var chartBody: some View {
        switch chart.state {
        case .loaded(let series):
            MultiSeriesChart(series: series).frame(height: 220)
        case .idle, .loading:
            StateView(.loading).frame(height: 220)
        case .empty:
            Text("No chart data yet.")
                .font(DSFont.subheadline)
                .foregroundStyle(DSColor.textSecondary)
                .frame(maxWidth: .infinity, minHeight: 220)
        case .failed(let message):
            VStack(spacing: DSLayout.spacingSmall) {
                Text(message).font(DSFont.subheadline).foregroundStyle(DSColor.textSecondary)
                Button("Retry") { Task { await chart.retry() } }.tint(DSColor.accent)
            }
            .frame(maxWidth: .infinity, minHeight: 220)
        }
    }
}
