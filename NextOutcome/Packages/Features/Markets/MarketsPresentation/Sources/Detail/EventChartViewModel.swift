import SwiftUI
import MarketsDomain
import OrderbookPresentation
import DesignSystem

/// Builds one price-history line per top outcome of an event for the MultiSeriesChart.
@MainActor
@Observable
public final class EventChartViewModel {
    private let event: Event
    private let provider: PriceHistoryProvider
    public var timeframe: ChartTimeframe = .max { didSet { Task { await load() } } }
    public private(set) var series: [PriceSeries] = []

    /// Monotonically increasing token used to discard stale `load()` results when
    /// rapid timeframe changes spawn overlapping unstructured Tasks (see `didSet` above).
    /// Only the most recently started `load()` call is allowed to write `series`.
    private var loadGeneration = 0

    public init(event: Event, provider: PriceHistoryProvider) {
        self.event = event
        self.provider = provider
    }

    /// Top markets (up to 4). Each market's Yes outcome token id drives one series.
    private var topMarkets: [Market] { Array(event.markets.prefix(4)) }

    public func load() async {
        loadGeneration += 1
        let generation = loadGeneration
        let interval = timeframe.interval
        var built: [PriceSeries] = []
        for (index, market) in topMarkets.enumerated() {
            guard let yes = market.yesOutcome else { continue }
            let history = await provider(yes.id, interval)
            let points = history.map { PricePoint(date: $0.date, price: NSDecimalNumber(decimal: $0.price).doubleValue) }
            let fallback = points.isEmpty
                ? [PricePoint(date: Date(), price: NSDecimalNumber(decimal: yes.price).doubleValue)]
                : points
            built.append(PriceSeries(id: market.id, label: market.question,
                                     color: OutcomePalette.color(index), points: fallback))
        }
        guard generation == loadGeneration else { return }
        series = built
    }
}
