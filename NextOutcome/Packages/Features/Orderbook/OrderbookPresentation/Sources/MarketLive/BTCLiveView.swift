//
//  BTCLiveView.swift
//  NextOutcome
//

import SwiftUI
import Charts
import OrderbookDomain
import DesignSystem

/// The BTC 5-minute live screen: candle/line chart with a dashed price-to-beat line, a
/// server-clock countdown (red under a minute), live Up/Down quick-bet buttons, and a
/// recent-trades ticker.
public struct BTCLiveView: View {
    /// The view model driving the whole screen.
    @State private var viewModel: BTCLiveViewModel

    /// Creates the view.
    /// - Parameter viewModel: The BTC-live view model (usually from `btcLiveFactory`).
    public init(viewModel: BTCLiveViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSLayout.spacingLarge) {
                header
                chartCard
                quickBet
                tradesTicker
            }
            .padding(DSLayout.spacing)
        }
        .background(DSColor.background.ignoresSafeArea())
        .onAppear { viewModel.start() }
        .onDisappear { viewModel.stop() }
    }

    // MARK: Header (countdown + price to beat)

    /// The header: the countdown on the left (red when urgent) and the price-to-beat on
    /// the right.
    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: DSLayout.spacingXSmall) {
                Text("Time remaining")
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.textSecondary)
                Text(viewModel.countdown)
                    .font(DSFont.price)
                    .foregroundStyle(viewModel.isCountdownUrgent ? DSColor.negative : DSColor.textPrimary)
            }
            Spacer()
            if let target = viewModel.priceToBeat {
                VStack(alignment: .trailing, spacing: DSLayout.spacingXSmall) {
                    Text("Price to beat")
                        .font(DSFont.caption)
                        .foregroundStyle(DSColor.textSecondary)
                    Text(centsLabel(target))
                        .font(DSFont.priceSmall)
                        .foregroundStyle(DSColor.textPrimary)
                }
            }
        }
    }

    // MARK: Chart

    /// The chart card: title, the candle/line mode toggle, and the chart body.
    private var chartCard: some View {
        DSCard {
            VStack(alignment: .leading, spacing: DSLayout.spacing) {
                HStack {
                    Text("BTC 5m")
                        .font(DSFont.headline)
                        .foregroundStyle(DSColor.textPrimary)
                    Spacer()
                    modeToggle
                }
                chartBody
                    .frame(height: 200)
            }
        }
    }

    /// The two chips that switch between candle and line chart modes.
    private var modeToggle: some View {
        HStack(spacing: DSLayout.spacingSmall) {
            DSChip("Candles", isActive: viewModel.chartMode == .candles) {
                viewModel.chartMode = .candles
            }
            DSChip("Line", isActive: viewModel.chartMode == .line) {
                viewModel.chartMode = .line
            }
        }
    }

    /// The chart contents, switching on load state (spinner / empty / error / the selected
    /// candle or line chart).
    @ViewBuilder
    private var chartBody: some View {
        switch viewModel.state {
        case .idle, .loading:
            ProgressView().frame(maxWidth: .infinity)
        case .empty:
            emptyOrError("No price data yet.", showRetry: false)
        case let .failed(message):
            emptyOrError(message, showRetry: true)
        case let .loaded(points):
            if viewModel.chartMode == .candles {
                candleChart
            } else {
                // Line mode reuses the C1 price-chart marks.
                PriceChart(data: points.map { PricePoint(date: $0.date, price: fractionValue($0.price)) })
            }
        }
    }

    /// The candlestick chart: a wick (high–low) and body (open–close) per candle, plus a
    /// dashed price-to-beat line. Green when the candle closed up, red when down.
    private var candleChart: some View {
        Chart {
            ForEach(Array(viewModel.candles.enumerated()), id: \.offset) { _, candle in
                // High–low wick.
                RuleMark(
                    x: .value("Time", candle.start),
                    yStart: .value("Low", fractionValue(candle.low)),
                    yEnd: .value("High", fractionValue(candle.high))
                )
                .foregroundStyle(candleColor(candle))
                // Open–close body.
                RectangleMark(
                    x: .value("Time", candle.start),
                    yStart: .value("Open", fractionValue(candle.open)),
                    yEnd: .value("Close", fractionValue(candle.close)),
                    width: .fixed(6)
                )
                .foregroundStyle(candleColor(candle))
            }
            if let target = viewModel.priceToBeat {
                RuleMark(y: .value("Price to beat", fractionValue(target)))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(DSColor.textSecondary)
            }
        }
        .chartYScale(domain: 0...1)
    }

    /// Green if the candle closed at or above its open, red otherwise.
    private func candleColor(_ candle: Candle) -> Color {
        candle.close >= candle.open ? DSColor.positive : DSColor.negative
    }

    // MARK: Quick bet

    /// The Up/Down quick-bet buttons showing the current live cents for each side.
    private var quickBet: some View {
        HStack(spacing: DSLayout.spacing) {
            PriceButton(
                title: "Up",
                price: centsButtonLabel(viewModel.upCents),
                style: .yes
            ) { viewModel.quickBet(.up) }
            PriceButton(
                title: "Down",
                price: centsButtonLabel(viewModel.downCents),
                style: .no
            ) { viewModel.quickBet(.down) }
        }
    }

    // MARK: Recent trades ticker

    /// The recent-trades list (up to 8 rows), hidden entirely when there are no trades.
    @ViewBuilder
    private var tradesTicker: some View {
        if !viewModel.recentTrades.isEmpty {
            DSCard {
                VStack(alignment: .leading, spacing: DSLayout.spacingSmall) {
                    Text("Recent trades")
                        .font(DSFont.headline)
                        .foregroundStyle(DSColor.textPrimary)
                    ForEach(viewModel.recentTrades.prefix(8)) { trade in
                        HStack {
                            Text(trade.side == .buy ? "Buy" : "Sell")
                                .font(DSFont.caption)
                                .foregroundStyle(trade.side == .buy ? DSColor.positive : DSColor.negative)
                            Text(trade.outcome)
                                .font(DSFont.caption)
                                .foregroundStyle(DSColor.textSecondary)
                            Spacer()
                            Text(centsLabel(trade.price))
                                .font(DSFont.priceSmall)
                                .foregroundStyle(DSColor.textPrimary)
                        }
                    }
                }
            }
        }
    }

    /// A centered message, optionally with a retry button, for the empty and error states.
    /// - Parameters:
    ///   - message: The text to show.
    ///   - showRetry: Whether to include a "Retry" button.
    private func emptyOrError(_ message: String, showRetry: Bool) -> some View {
        VStack(spacing: DSLayout.spacingSmall) {
            Text(message)
                .font(DSFont.caption)
                .foregroundStyle(DSColor.textSecondary)
            if showRetry {
                Button("Retry") { Task { await viewModel.retry() } }
                    .font(DSFont.subheadline)
                    .foregroundStyle(DSColor.accent)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Formatting (Decimal stays domain-side; Double/labels only here)

    /// Clamps a domain `Decimal` price into a 0…1 `Double` for the chart's y-axis.
    private func fractionValue(_ value: Decimal) -> Double {
        min(1, max(0, NSDecimalNumber(decimal: value).doubleValue))
    }

    /// Formats a 0…1 price as a whole-cent label (e.g. "62¢").
    private func centsLabel(_ value: Decimal) -> String {
        "\(Int((fractionValue(value) * 100).rounded()))¢"
    }

    /// Formats an optional cents value for a quick-bet button, showing "--" when unknown.
    private func centsButtonLabel(_ cents: Int?) -> String {
        cents.map { "\($0)¢" } ?? "--"
    }
}
