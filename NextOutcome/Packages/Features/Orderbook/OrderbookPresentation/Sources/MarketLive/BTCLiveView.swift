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

    /// The header: the countdown on the left (red when urgent), and the dollar
    /// price-to-beat + current price on the right (with a colored delta, matching web).
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
            HStack(alignment: .firstTextBaseline, spacing: DSLayout.spacing) {
                if let target = viewModel.priceToBeat {
                    VStack(alignment: .trailing, spacing: DSLayout.spacingXSmall) {
                        Text("Price to beat")
                            .font(DSFont.caption)
                            .foregroundStyle(DSColor.textSecondary)
                        Text(usdLabel(target))
                            .font(DSFont.priceSmall)
                            .foregroundStyle(DSColor.textPrimary)
                    }
                }
                if let current = viewModel.currentPrice {
                    VStack(alignment: .trailing, spacing: DSLayout.spacingXSmall) {
                        HStack(spacing: 4) {
                            Text("Current Price")
                                .font(DSFont.caption)
                                .foregroundStyle(DSColor.textSecondary)
                            if let delta = viewModel.priceDelta {
                                Text(deltaLabel(delta))
                                    .font(DSFont.caption)
                                    .foregroundStyle(delta >= 0 ? DSColor.positive : DSColor.negative)
                            }
                        }
                        Text(usdLabel(current))
                            .font(DSFont.priceSmall)
                            .foregroundStyle(DSColor.textPrimary)
                    }
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

    /// The three chips that switch between the dollar price line, the probability
    /// "chance" line, and dollar candlesticks — matching web's three chart styles.
    private var modeToggle: some View {
        HStack(spacing: DSLayout.spacingSmall) {
            DSChip("Price", isActive: viewModel.chartMode == .price) {
                viewModel.chartMode = .price
            }
            DSChip("Chance", isActive: viewModel.chartMode == .chance) {
                viewModel.chartMode = .chance
            }
            DSChip("Candles", isActive: viewModel.chartMode == .candles) {
                viewModel.chartMode = .candles
            }
        }
    }

    /// The chart contents, switching on the selected mode and its backing load state
    /// (spinner / empty / error / the selected chart).
    @ViewBuilder
    private var chartBody: some View {
        switch viewModel.chartMode {
        case .chance:
            chanceChartBody
        case .price, .candles:
            spotChartBody
        }
    }

    /// The "Chance" mode body: the probability line, driven by `viewModel.state`.
    @ViewBuilder
    private var chanceChartBody: some View {
        switch viewModel.state {
        case .idle, .loading:
            ProgressView().frame(maxWidth: .infinity)
        case .empty:
            emptyOrError("No price data yet.", showRetry: false)
        case let .failed(message):
            emptyOrError(message, showRetry: true)
        case let .loaded(points):
            PriceChart(data: points.map { PricePoint(date: $0.date, price: fractionValue($0.price)) })
        }
    }

    /// The "Price"/"Candles" mode body: the dollar spot-price line or candles, driven by
    /// `viewModel.spotState`.
    @ViewBuilder
    private var spotChartBody: some View {
        switch viewModel.spotState {
        case .idle, .loading:
            ProgressView().frame(maxWidth: .infinity)
        case .empty:
            emptyOrError("No price data yet.", showRetry: false)
        case .failed:
            emptyOrError("Couldn't load the live BTC price.", showRetry: false)
        case let .loaded(points):
            if viewModel.chartMode == .candles {
                candleChart
            } else {
                dollarLineChart(points)
            }
        }
    }

    /// The dollar price line: a bespoke Swift Charts area+line (rather than the shared
    /// `PriceChart`, which hardcodes a percent Y-axis used by probability/portfolio
    /// charts elsewhere), auto-scaled to the spot-price range, plus a dashed
    /// price-to-beat line.
    private func dollarLineChart(_ points: [CryptoSpotPricePoint]) -> some View {
        Chart {
            ForEach(points, id: \.date) { point in
                AreaMark(
                    x: .value("Time", point.date),
                    y: .value("Price", doubleValue(point.price))
                )
                .foregroundStyle(DSGradient.positiveArea)
                LineMark(
                    x: .value("Time", point.date),
                    y: .value("Price", doubleValue(point.price))
                )
                .foregroundStyle(DSColor.positive)
                .lineStyle(StrokeStyle(lineWidth: 2))
            }
            if let target = viewModel.priceToBeat {
                RuleMark(y: .value("Price to beat", doubleValue(target)))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(DSColor.textSecondary)
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) {
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(DSColor.separator)
                AxisValueLabel()
                    .foregroundStyle(DSColor.textSecondary)
                    .font(DSFont.caption2)
            }
        }
        .chartYScale(domain: spotYDomain)
    }

    /// The candlestick chart: a wick (high–low) and body (open–close) per dollar candle,
    /// plus a dashed price-to-beat line. Green when the candle closed up, red when down.
    /// The Y domain is auto-scaled to the price range (unlike the old probability-based
    /// candles, which were fixed to 0...1).
    private var candleChart: some View {
        Chart {
            ForEach(Array(viewModel.candles.enumerated()), id: \.offset) { _, candle in
                // High–low wick.
                RuleMark(
                    x: .value("Time", candle.start),
                    yStart: .value("Low", doubleValue(candle.low)),
                    yEnd: .value("High", doubleValue(candle.high))
                )
                .foregroundStyle(candleColor(candle))
                // Open–close body.
                RectangleMark(
                    x: .value("Time", candle.start),
                    yStart: .value("Open", doubleValue(candle.open)),
                    yEnd: .value("Close", doubleValue(candle.close)),
                    width: .fixed(6)
                )
                .foregroundStyle(candleColor(candle))
            }
            if let target = viewModel.priceToBeat {
                RuleMark(y: .value("Price to beat", doubleValue(target)))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(DSColor.textSecondary)
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) {
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(DSColor.separator)
                AxisValueLabel()
                    .foregroundStyle(DSColor.textSecondary)
                    .font(DSFont.caption2)
            }
        }
        .chartYScale(domain: spotYDomain)
    }

    /// The dollar charts' y-axis domain: the spot-price bounds padded by ~15% of the range
    /// (with small floors) so candle bodies and the price-to-beat line are clearly visible,
    /// instead of collapsing onto a 0-based auto-scaled axis. Falls back to `0…1` when there's
    /// no data (the chart isn't rendered in that state).
    private var spotYDomain: ClosedRange<Double> {
        guard let bounds = viewModel.spotPriceBounds else { return 0...1 }
        let low = doubleValue(bounds.min)
        let high = doubleValue(bounds.max)
        let pad = max((high - low) * 0.15, high * 0.0005, 1)
        return (low - pad)...(high + pad)
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

    /// Converts a dollar `Decimal` to an unclamped `Double` for the spot-price charts
    /// (unlike `fractionValue`, which clamps into 0…1 for probability charts).
    private func doubleValue(_ value: Decimal) -> Double {
        NSDecimalNumber(decimal: value).doubleValue
    }

    /// Formats a dollar `Decimal` as USD (e.g. "$63,945.94").
    private func usdLabel(_ value: Decimal) -> String {
        Self.usdFormatter.string(from: NSDecimalNumber(decimal: value)) ?? "$--"
    }

    /// Formats a signed dollar delta with an arrow (e.g. "▲$15", "▼$8").
    private func deltaLabel(_ value: Decimal) -> String {
        let magnitude = usdLabel(abs(value))
        return value >= 0 ? "▲\(magnitude)" : "▼\(magnitude)"
    }

    /// A shared USD currency formatter for `usdLabel`/`deltaLabel`.
    private static let usdFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter
    }()
}
