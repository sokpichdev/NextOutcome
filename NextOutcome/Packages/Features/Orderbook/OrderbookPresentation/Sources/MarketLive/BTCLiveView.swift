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

    /// The candle chart's opening scroll position, captured once the first series lands.
    /// Held in `@State` rather than recomputed per body pass so `chartScrollPosition`'s
    /// "initial" value is genuinely initial — see `candleChartBody`.
    @State private var initialAnchor: Date?

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
                // Each section is its own View struct so its observation scope is its own:
                // the 1 Hz countdown and the per-frame order book must not invalidate the
                // candle chart. See `BTCLiveSections.swift`.
                BTCLiveHeaderSection(viewModel: viewModel)
                chartCard
                BTCLiveQuickBetSection(viewModel: viewModel, onNextWindow: onNextWindow)
                BTCLiveTradesTicker(viewModel: viewModel)
            }
            .padding(DSLayout.spacing)
        }
        .background(DSColor.background.ignoresSafeArea())
        .onAppear { viewModel.start() }
        .onDisappear { viewModel.stop() }
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
    /// `BTCLiveViewModel.seedCandlePages`), opening anchored at the newest candle and then
    /// holding wherever the user leaves it.
    ///
    /// **Everything here exists to keep the candles still.** A live tick must move the
    /// current-price line and nothing else, so nothing whose size or value depends on the
    /// price may participate in the chart's layout:
    ///
    /// - The price chip is a `chartOverlay`, not an `.annotation` (`priceTagOverlay`), and
    ///   the y-axis labels have a reserved width. Both otherwise sit *outside* the plot
    ///   rect, so their width — which changes with the digits, `Font.caption2` having
    ///   proportional figures — resized the plot and slid every candle sideways.
    /// - The y-domain comes from `BTCLiveViewModel.candleDomain`, which only moves when the
    ///   price leaves its band, rather than refitting the series on every tick.
    /// - `initialAnchor` is captured once; `trailingScrollAnchor()` anchors the scroll view
    ///   at the newest candle without re-anchoring when a candle appends.
    ///
    /// Deliberately **not** bound to `chartScrollPosition(x:)` either: with live ticks
    /// mutating the forming candle many times a second, Swift Charts desyncs that binding
    /// from its real viewport — renders then alternate between the two positions, and
    /// prepending older pages teleports the view hours back. Scrolling stays entirely
    /// inside the chart's own gesture handling.
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
        // The stabilised band from the view model: it only moves when the price actually
        // leaves it, so an ordinary tick can't rescale the chart. `dollarDomain` remains
        // the fallback for the brief pre-seed window (and for the two line charts).
        let domain = viewModel.candleDomain ?? dollarDomain(
            low: candles.map { doubleValue($0.low) }.min(),
            high: candles.map { doubleValue($0.high) }.max()
        )
        // The x-domain, stated explicitly and carried one whole interval past the newest
        // candle. Left to infer it, Swift Charts ends the domain at `last.start` — and
        // because a `RectangleMark` is *centred* on its x value, the newest candle then
        // straddles the plot's right edge and gets sliced in half. The extra interval is
        // the same one `trailingAnchor` already assumes, so the two now agree.
        let lastStart = candles.last?.start ?? .now
        let xDomain = (candles.first?.start ?? lastStart)...lastStart.addingTimeInterval(interval)
        // The left edge that puts the newest candle at the right edge of the frame.
        let trailingAnchor = lastStart.addingTimeInterval(interval - visibleSpan)
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
            // The live price line: the value that actually moves while a window is open.
            // Coloured against the price to beat, so the line and the forming candle agree
            // on who is winning. Its label is drawn in `.chartOverlay` below, not as an
            // `.annotation` — see `priceTagOverlay`.
            if let current = viewModel.currentPrice {
                RuleMark(y: .value("Current price", doubleValue(current)))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 3]))
                    .foregroundStyle(currentPriceColor)
            }
        }
        .chartOverlay { proxy in priceTagOverlay(proxy) }
        .chartScrollableAxes(.horizontal)
        .chartXScale(domain: xDomain)
        .chartXVisibleDomain(length: visibleSpan)
        // Captured once, on the first non-empty series. Recomputing `trailingAnchor` every
        // body pass meant this modifier's value changed each time a new 5-minute bucket
        // opened, and Swift Charts can re-apply an "initial" position when it does.
        .chartScrollPosition(initialX: initialAnchor ?? trailingAnchor)
        .trailingScrollAnchor()
        .chartYScale(domain: domain)
        // Tick-driven data changes must never animate: an interpolating chart is a moving
        // chart. No implicit-animation source lives in this file, but ancestor
        // transactions (the enclosing ScrollView's layout, a mode-chip tap) propagate.
        .transaction { $0.animation = nil }
        // This body only exists once `candles` is non-empty (see `candleChart`), so its
        // first appearance is exactly the moment the opening anchor becomes meaningful.
        .onAppear { if initialAnchor == nil { initialAnchor = trailingAnchor } }
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
            AxisMarks(values: .automatic(desiredCount: 3)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(DSColor.separator)
                // A reserved width and tabular figures. The axis gutter is the *other*
                // thing whose size feeds back into the plot width — and therefore into
                // every candle's x position — so it must not depend on how many digits
                // the current band happens to print.
                AxisValueLabel {
                    Text(LiveFormat.axis(value.as(Double.self)))
                        .font(DSFont.caption2)
                        .monospacedDigit()
                        .lineLimit(1)
                        .foregroundStyle(DSColor.textSecondary)
                        .frame(width: Self.axisGutterWidth, alignment: .trailing)
                }
            }
        }
    }

    // MARK: Candle chart chrome

    /// The width of the trailing gutter: the y-axis labels' frame and the live price chip
    /// both take it, so the chip lands exactly in the axis column.
    ///
    /// Fixed rather than measured because the gutter is laid out *outside* the plot — a
    /// label that changed width with the digits would change the plot width, and therefore
    /// every candle's x position. Sized for a seven-figure price ("104,250") so neither the
    /// labels nor the chip can ever be forced to truncate.
    private static let axisGutterWidth: CGFloat = 52

    /// The gap between the price chip and the trailing edge of the chart.
    private static let priceTagInset: CGFloat = 2

    /// The live price chip, drawn on top of the plot at the current-price line.
    ///
    /// Deliberately an overlay rather than the `.annotation` this used to be: Swift Charts
    /// lays annotations out *outside* the plot rect, so the label's width was subtracted
    /// from the plot width. With proportional figures, `$63,911.11` and `$63,988.88` are
    /// different widths, so every tick resized the plot, rescaled `chartXVisibleDomain`,
    /// and slid every candle sideways — the reported "flickering forward backward".
    /// Overlays contribute nothing to chart layout.
    ///
    /// It also fixes a correctness bug the annotation had: `plotFrame` spans the whole
    /// scroll *content*, so its trailing edge is hours off-screen once the user scrolls
    /// back through history — the chip simply vanished. Clamping to the overlay's own
    /// bounds, which are the viewport, keeps it pinned to the right edge of what's visible.
    @ViewBuilder
    private func priceTagOverlay(_ proxy: ChartProxy) -> some View {
        GeometryReader { geometry in
            if let current = viewModel.currentPrice,
               let anchor = proxy.plotFrame,
               let offset = proxy.position(forY: doubleValue(current)) {
                let plot = geometry[anchor]
                // Pinned to the chart's own trailing edge, not `plot.maxX`: the chip
                // belongs in the y-axis gutter, beside the other value labels, so it never
                // covers the newest candles. (`plot.maxX` is the trailing edge of the
                // scroll *content* anyway — hours off-screen once the user scrolls back,
                // which is why the old annotation simply vanished.)
                let rightEdge = geometry.size.width - Self.priceTagInset
                priceTag(current)
                    .position(x: rightEdge - Self.axisGutterWidth / 2, y: plot.minY + offset)
            }
        }
        // The chart owns the horizontal drag; an overlay that swallowed touches would kill
        // scroll-back through history.
        .allowsHitTesting(false)
    }

    /// The price chip itself: the live price in the y-axis's own format and column width,
    /// so it reads as a highlighted axis value rather than a callout floating over the
    /// candles. The header carries the full `US$63,820.30` with cents.
    ///
    /// `monospacedDigit` keeps the text from shifting inside the fixed frame as the digits
    /// change.
    private func priceTag(_ value: Decimal) -> some View {
        Text(LiveFormat.axis(doubleValue(value)))
            .font(DSFont.caption2.bold())
            .monospacedDigit()
            .lineLimit(1)
            .foregroundStyle(.white)
            .padding(.vertical, 2)
            .frame(width: Self.axisGutterWidth)
            .background(currentPriceColor, in: RoundedRectangle(cornerRadius: 4))
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

    // MARK: Formatting

    // Thin call-site aliases onto `LiveFormat` (shared with the section views), so the
    // chart code below reads as `doubleValue(candle.low)` rather than a qualified call.

    /// Clamps a domain `Decimal` price into a 0…1 `Double` for the probability chart's axis.
    private func fractionValue(_ value: Decimal) -> Double { LiveFormat.fraction(value) }

    /// Converts a dollar `Decimal` to an unclamped `Double` for the spot-price charts.
    private func doubleValue(_ value: Decimal) -> Double { LiveFormat.double(value) }

    /// Formats a dollar `Decimal` as USD (e.g. "$63,945.94").
    private func usdLabel(_ value: Decimal) -> String { LiveFormat.usd(value) }
}

/// Anchors a scrollable chart at its trailing edge **once**, without re-anchoring later.
///
/// `defaultScrollAnchor(_:)` maintains the anchor across content-size changes, so every
/// appended candle yanked a scrolled-back user forward to the newest one. The
/// `.initialOffset` role expresses what we actually want — open on the newest candle, then
/// leave the offset alone. The app deploys to iOS 26; the `else` branch only exists to
/// honour the package's iOS 17 floor.
private struct TrailingScrollAnchor: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 18.0, macOS 15.0, *) {
            content.defaultScrollAnchor(.trailing, for: .initialOffset)
        } else {
            content.defaultScrollAnchor(.trailing)
        }
    }
}

private extension View {
    /// Applies `TrailingScrollAnchor`.
    func trailingScrollAnchor() -> some View { modifier(TrailingScrollAnchor()) }
}
