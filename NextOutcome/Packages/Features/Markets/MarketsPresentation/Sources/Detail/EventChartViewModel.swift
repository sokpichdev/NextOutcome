import SwiftUI
import MarketsDomain
import OrderbookPresentation
import DesignSystem
import SharedDomain

/// Builds one price-history line per top outcome of an event for the MultiSeriesChart.
@MainActor
@Observable
public final class EventChartViewModel {
    /// The event whose outcomes are charted.
    private let event: Event
    /// Supplies price-history data per outcome token.
    private let provider: PriceHistoryProvider
    /// The selected timeframe; changing it reloads the chart.
    public var timeframe: ChartTimeframe = .max { didSet { Task { await load() } } }
    /// The chart series, wrapped in a load state.
    public private(set) var state: LoadState<[PriceSeries]> = .idle

    /// Monotonically increasing token used to discard stale `load()` results when
    /// rapid timeframe changes spawn overlapping unstructured Tasks (see `didSet` above).
    /// Only the most recently started `load()` call is allowed to write `state`.
    private var loadGeneration = 0

    /// Creates the view model.
    /// - Parameters:
    ///   - event: The event to chart.
    ///   - provider: The price-history data source.
    public init(event: Event, provider: PriceHistoryProvider) {
        self.event = event
        self.provider = provider
    }

    /// The top 4 markets by current Yes probability, preferring still-open markets. Each
    /// market's Yes outcome token id drives one series.
    ///
    /// A multi-candidate event (e.g. "GPT-5.6 released on…?" — one market per specific day,
    /// all sharing the same settlement date) can carry dozens of sibling markets, most of
    /// them already-resolved noise from days that came and went. Taking Gamma's raw array
    /// order picked whichever 4 happened to appear first — often stale closed markets —
    /// instead of the handful of dates actually still in play. Sorting by Yes price descending
    /// (over the open markets, falling back to everything if the event is fully resolved)
    /// surfaces the real leaders, matching the live site's legend.
    private var topMarkets: [Market] {
        let open = event.markets.filter { !$0.isResolved }
        let candidates = open.isEmpty ? event.markets : open
        return Array(candidates.sorted { ($0.yesOutcome?.price ?? 0) > ($1.yesOutcome?.price ?? 0) }.prefix(4))
    }

    /// Loads one price-history series per top market, in parallel, keeping the previous
    /// chart visible while new data loads. Uses `loadGeneration` to ignore results from a
    /// superseded load when the timeframe changes rapidly.
    public func load() async {
        loadGeneration += 1
        let generation = loadGeneration
        if case .loaded = state {
            // keep showing the previous chart while new data loads
        } else {
            state = .loading
        }
        let interval = timeframe.interval
        let markets = topMarkets
        let provider = provider

        do {
            let built = try await withThrowingTaskGroup(of: (Int, PriceSeries).self) { group in
                for (index, market) in markets.enumerated() {
                    guard let yes = market.yesOutcome else { continue }
                    group.addTask {
                        let history = try await provider(yes.id, interval)
                        let points = history.map { PricePoint(date: $0.date, price: NSDecimalNumber(decimal: $0.price).doubleValue) }
                        let fallback = points.isEmpty
                            ? [PricePoint(date: Date(), price: NSDecimalNumber(decimal: yes.price).doubleValue)]
                            : points
                        return (index, PriceSeries(id: market.id, label: market.groupItemTitle ?? market.question,
                                                   color: OutcomePalette.color(index), points: fallback))
                    }
                }
                var results: [(Int, PriceSeries)] = []
                for try await item in group { results.append(item) }
                return results.sorted { $0.0 < $1.0 }.map(\.1)
            }
            guard generation == loadGeneration else { return }
            state = built.isEmpty ? .empty : .loaded(built)
        } catch {
            guard generation == loadGeneration else { return }
            state = .failed(message: "Couldn't load chart data. Check your connection and try again.")
        }
    }

    /// Re-runs `load()` with the current `timeframe`, e.g. after a `.failed` state.
    public func retry() async {
        await load()
    }
}
