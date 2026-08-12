import SwiftUI
import MarketsDomain
import OrderbookPresentation
import DesignSystem
import SharedDomain

/// Builds one price-history line per top outcome of an event for the MultiSeriesChart.
@MainActor
@Observable
public final class EventChartViewModel {
    /// Which outcomes to draw as lines.
    public enum Source {
        /// One line per top market's leading outcome — the default for an event page, where
        /// each market is a different question.
        case topMarkets(limit: Int)
        /// One line per outcome of a *single* market, coloured by `colors` (index-matched,
        /// falling back to `OutcomePalette`). This is how web charts an esports match: the
        /// two sides of the moneyline against each other, in their team colours, rather than
        /// one line each from four unrelated map markets.
        case outcomes(of: Market, colors: [Color])
    }

    /// The event whose outcomes are charted.
    private let event: Event
    /// Supplies price-history data per outcome token.
    private let provider: PriceHistoryProvider
    /// Which outcomes are drawn.
    private let source: Source
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
    ///   - source: Which outcomes to draw. Defaults to the top four markets.
    public init(event: Event, provider: PriceHistoryProvider, source: Source = .topMarkets(limit: 4)) {
        self.event = event
        self.provider = provider
        self.source = source
    }

    /// One line to draw: which token to fetch, how to label it, and what colour to use.
    private struct SeriesPlan {
        /// Stable identity for the resulting `PriceSeries`.
        let id: String
        /// The CLOB token whose price history backs the line.
        let tokenID: String
        /// The legend label.
        let label: String
        /// The line colour.
        let color: Color
        /// The current price, drawn as a single point when no history comes back.
        let currentPrice: Decimal
    }

    /// Resolves `source` into the lines to draw.
    ///
    /// Reads `primaryOutcome` rather than `yesOutcome`: a sports or esports market names its
    /// outcomes after the teams, so keying on "Yes" skipped them and drew an empty chart.
    private var plan: [SeriesPlan] {
        switch source {
        case .topMarkets(let limit):
            return event.markets.prefix(limit).enumerated().compactMap { index, market in
                guard let outcome = market.primaryOutcome else { return nil }
                return SeriesPlan(id: market.id, tokenID: outcome.id,
                                  label: market.groupItemTitle ?? market.question,
                                  color: OutcomePalette.color(index),
                                  currentPrice: outcome.price)
            }
        case .outcomes(let market, let colors):
            return market.outcomes.enumerated().map { index, outcome in
                SeriesPlan(id: "\(market.id)-\(outcome.id)", tokenID: outcome.id,
                           label: outcome.title,
                           color: colors.indices.contains(index) ? colors[index] : OutcomePalette.color(index),
                           currentPrice: outcome.price)
            }
        }
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
        let plan = plan
        let provider = provider

        do {
            let built = try await withThrowingTaskGroup(of: (Int, PriceSeries).self) { group in
                for (index, line) in plan.enumerated() {
                    group.addTask {
                        let history = try await provider(line.tokenID, interval)
                        let points = history.map { PricePoint(date: $0.date, price: NSDecimalNumber(decimal: $0.price).doubleValue) }
                        let fallback = points.isEmpty
                            ? [PricePoint(date: Date(), price: NSDecimalNumber(decimal: line.currentPrice).doubleValue)]
                            : points
                        return (index, PriceSeries(id: line.id, label: line.label,
                                                   color: line.color, points: fallback))
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
