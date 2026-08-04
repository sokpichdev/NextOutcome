//
//  BTCLiveView.swift
//  NextOutcome
//
//  Created by Sok Pich on 03/07/2026.
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

    /// Moves the user on once this window has closed. `nil` leaves the closed state as a
    /// dead end with an explanatory label rather than a button that goes nowhere.
    ///
    /// Injected rather than resolved here: finding the next window is a Markets concern
    /// (`ClockGriddedSeries`), and this screen lives in the Orderbook slice, which has no
    /// business depending on it.
    private let onNextWindow: (() -> Void)?

    /// Creates the view.
    /// - Parameters:
    ///   - viewModel: The BTC-live view model (usually from `btcLiveFactory`).
    ///   - onNextWindow: Invoked when the user taps through from a closed window.
    public init(viewModel: BTCLiveViewModel, onNextWindow: (() -> Void)? = nil) {
        self._viewModel = State(initialValue: viewModel)
        self.onNextWindow = onNextWindow
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
                Text(viewModel.hasSettled ? "Window closed" : "Time remaining")
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.textSecondary)
                if let settlement = viewModel.settlement {
                    settlementLabel(settlement)
                } else {
                    Text(viewModel.countdown)
                        .font(DSFont.price)
                        .foregroundStyle(viewModel.isCountdownUrgent ? DSColor.negative : DSColor.textPrimary)
                }
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
            chanceLineChart(points)
        }
    }

    /// The "Chance" line: probability over the window, as a percent.
    ///
    /// Bespoke rather than the shared `PriceChart` because that one pins its Y-axis to the
    /// full 0…100%, which flattens a window that only ever moves between 30% and 55% into a
    /// nearly straight line. Web scales this axis to the data too. Everything else — the
    /// monotone curve, the area fill, the last-point dot — matches the dollar chart so the
    /// three tabs read as one family.
    private func chanceLineChart(_ points: [PriceHistoryPoint]) -> some View {
        let values = points.map { fractionValue($0.price) }
        return Chart {
            ForEach(points, id: \.date) { point in
                AreaMark(
                    x: .value("Time", point.date),
                    y: .value("Chance", fractionValue(point.price))
                )
                .foregroundStyle(DSGradient.positiveArea)
                .interpolationMethod(.monotone)
                LineMark(
                    x: .value("Time", point.date),
                    y: .value("Chance", fractionValue(point.price))
                )
                .foregroundStyle(DSColor.positive)
                .lineStyle(StrokeStyle(lineWidth: 2))
                .interpolationMethod(.monotone)
            }
            if let last = points.last {
                PointMark(
                    x: .value("Time", last.date),
                    y: .value("Chance", fractionValue(last.price))
                )
                .foregroundStyle(DSColor.positive)
                .symbolSize(60)
            }
        }
        .chartYScale(domain: chanceDomain(low: values.min(), high: values.max()))
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(DSColor.separator)
                AxisValueLabel {
                    if let fraction = value.as(Double.self) {
                        Text("\(Int((fraction * 100).rounded()))%")
                            .foregroundStyle(DSColor.textSecondary)
                            .font(DSFont.caption2)
                    }
                }
            }
        }
    }

    /// Y range for the chance chart: fitted to the window's own movement, then clamped to
    /// 0…1 so padding can't produce a negative or >100% axis label.
    private func chanceDomain(low: Double?, high: Double?) -> ClosedRange<Double> {
        let lo = low ?? 0
        let hi = high ?? 1
        guard hi > lo else {
            let pad = 0.05
            return max(0, lo - pad)...min(1, hi + pad)
        }
        let pad = (hi - lo) * 0.15
        return max(0, lo - pad)...min(1, hi + pad)
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
        let values = points.map { doubleValue($0.price) }
        return Chart {
            ForEach(points, id: \.date) { point in
                AreaMark(
                    x: .value("Time", point.date),
                    y: .value("Price", doubleValue(point.price))
                )
                .foregroundStyle(DSGradient.positiveArea)
                .interpolationMethod(.monotone)
                LineMark(
                    x: .value("Time", point.date),
                    y: .value("Price", doubleValue(point.price))
                )
                .foregroundStyle(DSColor.positive)
                .lineStyle(StrokeStyle(lineWidth: 2))
                .interpolationMethod(.monotone)
            }
            if let last = points.last {
                PointMark(
                    x: .value("Time", last.date),
                    y: .value("Price", doubleValue(last.price))
                )
                .foregroundStyle(DSColor.positive)
                .symbolSize(60)
            }
            if let target = viewModel.priceToBeat {
                RuleMark(y: .value("Price to beat", doubleValue(target)))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(DSColor.textSecondary)
            }
        }
        .chartYScale(domain: dollarDomain(low: values.min(), high: values.max()))
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) {
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(DSColor.separator)
                AxisValueLabel()
                    .foregroundStyle(DSColor.textSecondary)
                    .font(DSFont.caption2)
            }
        }
    }

    /// How many candles fit in the chart frame at once; older candles scroll in from the
    /// left. 24 five-minute candles ≈ two hours on screen, matching the web's default zoom.
    private static let visibleCandleCount = 24

    /// The candlestick chart: a wick (high–low) and body (open–close) per 5-minute
    /// candle, plus a dashed price-to-beat line and the live current-price line.
    /// Green when the candle closed up, red when down.
    ///
    /// Scrolls horizontally through the seeded history (several hours; see
    /// `BTCLiveViewModel.seedCandlePages`), starting anchored at the newest candle.
    ///
    /// Deliberately **not** bound to `chartScrollPosition(x:)`: with live ticks mutating
    /// the forming candle many times a second, Swift Charts desyncs that binding from its
    /// real viewport — renders then alternate between the two positions (a once-a-second
    /// flicker) and prepending older pages teleports the view hours back. Scrolling stays
    /// entirely inside the chart's own gesture handling; only `initialX` anchors it once.
    @ViewBuilder
    private var candleChart: some View {
        if viewModel.candles.isEmpty {
            ProgressView().frame(maxWidth: .infinity)
        } else {
            candleChartBody
        }
    }

    private var candleChartBody: some View {
        let candles = viewModel.candles
        let interval = viewModel.windowInterval
        let visibleSpan = interval * Double(Self.visibleCandleCount)
        let domain = dollarDomain(
            low: candles.map { doubleValue($0.low) }.min(),
            high: candles.map { doubleValue($0.high) }.max()
        )
        // The left edge that puts the newest candle at the right edge of the frame.
        let trailingAnchor = (candles.last?.start ?? .now).addingTimeInterval(interval - visibleSpan)
        // A body thin enough to leave gaps between the visible candles, but never a hairline.
        let bodyWidth = max(3.0, min(14.0, 260.0 / Double(Self.visibleCandleCount)))
        // Open == close would give a zero-height rectangle, which draws nothing. Floor the
        // body to a sliver of the visible range so a flat candle still reads as a candle.
        let minBody = (domain.upperBound - domain.lowerBound) * 0.004
        return Chart {
            ForEach(candles, id: \.start) { candle in
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
                    yStart: .value("Open", bodyBounds(candle, minHeight: minBody).lower),
                    yEnd: .value("Close", bodyBounds(candle, minHeight: minBody).upper),
                    width: .fixed(bodyWidth)
                )
                .foregroundStyle(candleColor(candle))
            }
            if let target = viewModel.priceToBeat {
                RuleMark(y: .value("Price to beat", doubleValue(target)))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(DSColor.textSecondary)
            }
            // The live price line: the value that actually moves while a window is open,
            // labelled at the right edge the way the web does it. Coloured against the price
            // to beat, so the line and the forming candle agree on who is winning.
            if let current = viewModel.currentPrice {
                RuleMark(y: .value("Current price", doubleValue(current)))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 3]))
                    .foregroundStyle(currentPriceColor)
                    .annotation(position: .trailing, alignment: .trailing, spacing: 0) {
                        Text(usdLabel(current))
                            .font(DSFont.caption2.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(currentPriceColor)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
            }
        }
        .chartScrollableAxes(.horizontal)
        .chartXVisibleDomain(length: visibleSpan)
        .chartScrollPosition(initialX: trailingAnchor)
        // `initialX` alone is not reliably honoured (the chart can still open at its
        // oldest candle), so also anchor the underlying scroll view to the trailing edge.
        .defaultScrollAnchor(.trailing)
        .chartYScale(domain: domain)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(DSColor.separator)
                AxisValueLabel(format: .dateTime.hour().minute())
                    .foregroundStyle(DSColor.textSecondary)
                    .font(DSFont.caption2)
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
    }

    /// Y-axis range for the dollar charts, fitted to the data.
    ///
    /// Without this Swift Charts picks its own domain, and both `AreaMark` and
    /// `RectangleMark` anchor to zero — which put a ~$63,800 series on a 0…100,000 axis and
    /// turned the price line into a flat slab and the candles into a hairline.
    ///
    /// `priceToBeat` is folded in so the target line can never sit off-screen, and the band
    /// is padded so the extremes aren't glued to the frame edge.
    private func dollarDomain(low: Double?, high: Double?) -> ClosedRange<Double> {
        var lo = low ?? 0
        var hi = high ?? 1
        if let target = viewModel.priceToBeat {
            let value = doubleValue(target)
            lo = min(lo, value)
            hi = max(hi, value)
        }
        guard hi > lo else {
            // A perfectly flat series still needs a band, or the line lands on the frame edge.
            let pad = max(abs(hi) * 0.001, 1)
            return (lo - pad)...(hi + pad)
        }
        let pad = (hi - lo) * 0.08
        return (lo - pad)...(hi + pad)
    }

    /// The candle body's drawn bounds, widened to `minHeight` when open and close are equal
    /// so a flat candle still renders instead of collapsing to nothing.
    private func bodyBounds(_ candle: Candle, minHeight: Double) -> (lower: Double, upper: Double) {
        let open = doubleValue(candle.open)
        let close = doubleValue(candle.close)
        let lower = min(open, close)
        let upper = max(open, close)
        guard upper - lower < minHeight else { return (lower, upper) }
        let mid = (lower + upper) / 2
        return (mid - minHeight / 2, mid + minHeight / 2)
    }

    /// The live price line's colour: green while the price is at or above the window's open,
    /// red once it falls below — the same test the forming candle's body uses.
    private var currentPriceColor: Color {
        guard let current = viewModel.currentPrice, let target = viewModel.priceToBeat else {
            return DSColor.textSecondary
        }
        return current >= target ? DSColor.positive : DSColor.negative
    }

    /// Green if the candle closed at or above its open, red otherwise.
    private func candleColor(_ candle: Candle) -> Color {
        candle.close >= candle.open ? DSColor.positive : DSColor.negative
    }

    /// The settled result in place of the countdown: which side the window finished on.
    @ViewBuilder
    private func settlementLabel(_ settlement: BTCLiveViewModel.Settlement) -> some View {
        switch settlement {
        case .up:
            Text("Up won").font(DSFont.price).foregroundStyle(DSColor.positive)
        case .down:
            Text("Down won").font(DSFont.price).foregroundStyle(DSColor.negative)
        case .undetermined:
            Text("Settled").font(DSFont.price).foregroundStyle(DSColor.textSecondary)
        }
    }

    // MARK: Quick bet

    /// The Up/Down quick-bet buttons showing the current live cents for each side.
    ///
    /// Replaced once the window closes: a closed window's book empties out, so the buttons
    /// would read "--" and do nothing — which is exactly what made the ended screen look
    /// broken. The whole screen intentionally stays put on the window the user opened,
    /// showing how it finished, with one tap to move on.
    @ViewBuilder
    private var quickBet: some View {
        if viewModel.hasSettled {
            Button(action: { onNextWindow?() }) {
                Text(onNextWindow == nil ? "This window has closed" : "Next window →")
                    .font(DSFont.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DSLayout.spacingMedium)
            }
            .buttonStyle(.plain)
            .foregroundStyle(onNextWindow == nil ? DSColor.textSecondary : DSColor.accent)
            .background(DSColor.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: DSLayout.cardRadius))
            .disabled(onNextWindow == nil)
        } else {
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
