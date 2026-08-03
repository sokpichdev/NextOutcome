//
//  BTCLiveViewModel.swift
//  NextOutcome
//
//  Created by Sok Pich on 03/07/2026.
//

import Foundation
import OrderbookDomain
import SharedDomain
import DesignSystem

/// Drives the BTC 5-minute live screen: OHLC/line chart, price-to-beat, a server-clock
/// countdown, live quick-bet cents, and a recent-trades ticker.
///
/// Time handling: the authoritative server time is fetched **once** (`serverTime()`),
/// then the countdown ticks forward using a monotonic `ContinuousClock` offset — never
/// the device wall clock (which can drift) and never a refetch of `/time` per tick.
@MainActor
@Observable
public final class BTCLiveViewModel {
    /// Which chart representation to show. `.price`/`.candles` are real dollar spot
    /// prices; `.chance` is the CLOB contract-probability series (0…1).
    public enum ChartMode: Sendable { case price, chance, candles }
    /// Which side a quick-bet tap represents.
    public enum BetSide: Sendable { case up, down }

    /// The contract-probability series (0…1) backing the "Chance" chart mode, kept live
    /// by appending the order book's midpoint as new snapshots arrive (see `streamBook`).
    public private(set) var state: LoadState<[PriceHistoryPoint]> = .idle
    /// The real dollar BTC spot-price series backing the "Price" and "Candles" chart
    /// modes, seeded from REST history then kept live by folding in RTDS socket ticks
    /// (see `streamSpotPrice`).
    public private(set) var spotState: LoadState<[CryptoSpotPricePoint]> = .idle
    /// The window's dollar open/close snapshot — the source of `priceToBeat`.
    public private(set) var priceWindow: CryptoPriceWindow?
    /// The chart mode the user has selected.
    public var chartMode: ChartMode = .price
    /// Whether older candle pages may still exist server-side — `false` once a page
    /// comes back short, which is the feed's "end of history" signal.
    public private(set) var hasMoreCandles = false
    /// Whether a `loadMoreCandles()` page fetch is currently in flight (drives the
    /// chart's left-edge loading affordance and debounces scroll-triggered loads).
    public private(set) var isLoadingMoreCandles = false
    /// The formatted countdown string (e.g. "3:47") shown in the header.
    public private(set) var countdown: String = "--:--"
    /// Seconds left until the window closes, per the server-anchored clock.
    public private(set) var remainingSeconds: Int = 0
    /// The recent-trades ticker contents, refreshed by polling.
    public private(set) var recentTrades: [RecentTrade] = []
    /// The latest order book, used for the live Up/Down cents.
    public private(set) var book: OrderBook?

    /// The rolling window used to pick the price-to-beat (5 minutes).
    public let windowInterval: TimeInterval = 300

    /// The "Up" outcome token being charted/traded.
    private let assetID: String
    /// The event id used by the recent-trades poll.
    private let eventID: String
    /// When the current 5-minute window closes.
    private let windowEnd: Date
    /// The underlying crypto asset's ticker symbol (e.g. "BTC", "ETH"), used to query
    /// the real dollar spot-price feed — this screen opens for any Up/Down coin, not
    /// just Bitcoin.
    private let symbol: String
    /// Use case that loads the price series.
    private let fetchHistory: FetchPriceHistoryUseCase
    /// Use case that fetches authoritative server time (fetched once).
    private let fetchServerTime: FetchServerTimeUseCase
    /// Use case that polls recent trades.
    private let fetchRecentTrades: FetchRecentTradesUseCase
    /// Use case that streams the live book.
    private let observeBook: ObserveOrderBookUseCase
    /// Use case that streams the live dollar spot-price series: seeds via REST, then folds
    /// live RTDS socket ticks. Replaces the former 5-second spot-price poll so "Current
    /// Price" ticks in real time, matching web.
    private let observeSpotPrice: ObserveCryptoSpotPriceUseCase
    /// Use case that polls the window's dollar open/close snapshot.
    private let fetchPriceWindow: FetchCryptoPriceWindowUseCase
    /// Use case that pages the real OHLC candle history (the chainlink-candles feed).
    private let fetchCandles: FetchCryptoCandlesUseCase
    /// Callback invoked when the user taps Up/Down (host opens the trade flow).
    private let onQuickBet: @MainActor (BetSide) -> Void

    /// Drives the once-per-second countdown refresh.
    private var tickTask: Task<Void, Never>?
    /// Consumes the live book stream.
    private var bookTask: Task<Void, Never>?
    /// Polls recent trades on a timer.
    private var tradesTask: Task<Void, Never>?
    /// Runs the initial history + server-time load.
    private var loadTask: Task<Void, Never>?
    /// Consumes the live dollar spot-price stream.
    private var spotTask: Task<Void, Never>?
    /// Polls the window's dollar open/close snapshot on a timer (it isn't on the live tick
    /// feed, so it stays a low-frequency poll).
    private var windowTask: Task<Void, Never>?
    /// Loads the initial candle-history page.
    private var candlesTask: Task<Void, Never>?
    /// The real candle history from the chainlink-candles feed, oldest first, with the
    /// forming (newest) candle kept live by folding in RTDS ticks. Empty until the seed
    /// page arrives (or forever, if the feed fails — `candles` then falls back to
    /// bucketing the window-scoped spot series).
    private var candleSeries: [Candle] = []
    /// Set once `stop()` runs; guards against a late-completing `load()` resurrecting
    /// the countdown ticker (or spawning other work) after teardown.
    private(set) var isStopped = false

    /// A monotonic clock that never jumps (unlike wall-clock `Date`), used to advance the
    /// countdown from the server anchor.
    private let monoClock = ContinuousClock()
    /// The server time captured at load, the anchor the countdown counts from.
    private var serverAnchor: Date?
    /// The monotonic instant captured at the same moment as `serverAnchor`.
    private var monoAnchor: ContinuousClock.Instant?

    /// Creates the view model. Usually built via `BTCLiveViewModelFactory`, not directly.
    /// - Parameters:
    ///   - assetID: The "Up" outcome token.
    ///   - eventID: The event id for the trades ticker.
    ///   - windowEnd: When the 5-minute window closes.
    ///   - symbol: The underlying crypto asset's ticker symbol (e.g. "BTC", "ETH").
    ///   - fetchHistory: Loads the price series.
    ///   - fetchServerTime: Fetches authoritative server time (once).
    ///   - fetchRecentTrades: Polls recent trades.
    ///   - observeBook: Streams the live book.
    ///   - observeSpotPrice: Streams the live dollar spot-price series (seed + socket).
    ///   - fetchPriceWindow: Polls the window's dollar open/close snapshot.
    ///   - fetchCandles: Pages the real OHLC candle history.
    ///   - onQuickBet: Called when the user taps Up/Down.
    public init(
        assetID: String,
        eventID: String,
        windowEnd: Date,
        symbol: String,
        fetchHistory: FetchPriceHistoryUseCase,
        fetchServerTime: FetchServerTimeUseCase,
        fetchRecentTrades: FetchRecentTradesUseCase,
        observeBook: ObserveOrderBookUseCase,
        observeSpotPrice: ObserveCryptoSpotPriceUseCase,
        fetchPriceWindow: FetchCryptoPriceWindowUseCase,
        fetchCandles: FetchCryptoCandlesUseCase,
        onQuickBet: @escaping @MainActor (BetSide) -> Void
    ) {
        self.assetID = assetID
        self.eventID = eventID
        self.windowEnd = windowEnd
        self.symbol = symbol
        self.fetchHistory = fetchHistory
        self.fetchServerTime = fetchServerTime
        self.fetchRecentTrades = fetchRecentTrades
        self.observeBook = observeBook
        self.observeSpotPrice = observeSpotPrice
        self.fetchPriceWindow = fetchPriceWindow
        self.fetchCandles = fetchCandles
        self.onQuickBet = onQuickBet
    }

    // MARK: Derived

    /// Dollar OHLC candles for the "Candles" chart mode, oldest first.
    ///
    /// **One candle per betting window** (5 minutes here), matching the web: the primary
    /// source is the chainlink-candles feed, which serves real multi-hour history and
    /// pages arbitrarily far back (`loadMoreCandles`). The newest candle is the window
    /// currently forming; live RTDS ticks fold into it in place (close tracks the tick,
    /// high/low stretch, colour flips as close crosses open) — see `streamSpotPrice`.
    ///
    /// Until the feed's seed page arrives — or if it fails outright — this falls back to
    /// bucketing the window-scoped spot series, which can only ever produce the current
    /// window's single forming candle (that feed returns nothing outside the window, so
    /// asking it for two hours still yields ~300s of samples).
    public var candles: [Candle] {
        if !candleSeries.isEmpty { return candleSeries }
        guard case let .loaded(points) = spotState, !points.isEmpty else { return [] }
        return Self.bucket(points.sorted { $0.date < $1.date }, interval: windowInterval)
    }

    /// The candle width to request, derived from this market's window length.
    private var candleInterval: CandleInterval {
        windowInterval >= 900 ? .fifteenMinute : .fiveMinute
    }

    /// Groups a price series into fixed-width buckets, one candle each.
    ///
    /// Buckets are anchored to absolute time (`floor(t / interval)`), not to the first
    /// sample, so a candle keeps its boundaries as the series grows — otherwise every new
    /// point would shift every bar.
    /// - Parameters:
    ///   - points: The price series, ascending by date.
    ///   - interval: The bucket width in seconds.
    /// - Returns: One candle per non-empty bucket, ascending.
    nonisolated static func bucket(_ points: [CryptoSpotPricePoint], interval: TimeInterval) -> [Candle] {
        guard interval > 0 else { return [] }
        var candles: [Candle] = []
        var bucketStart: Date?
        var open: Decimal = 0, high: Decimal = 0, low: Decimal = 0, close: Decimal = 0

        for point in points {
            let slot = (point.date.timeIntervalSince1970 / interval).rounded(.down) * interval
            let start = Date(timeIntervalSince1970: slot)
            if start != bucketStart {
                if let bucketStart {
                    candles.append(Candle(open: open, high: high, low: low, close: close, start: bucketStart))
                }
                bucketStart = start
                open = point.price
                high = point.price
                low = point.price
            } else {
                high = Swift.max(high, point.price)
                low = Swift.min(low, point.price)
            }
            close = point.price
        }
        if let bucketStart {
            candles.append(Candle(open: open, high: high, low: low, close: close, start: bucketStart))
        }
        return candles
    }

    /// The dollar "price to beat" — the window's open price. Before the first
    /// spot-price poll completes (`priceWindow == nil`), falls back to the probability
    /// series' window-open sample so the header isn't blank on entry. Once polled, this
    /// defers entirely to the server: if `priceWindow.openPrice` is genuinely `null`
    /// (e.g. the window hasn't opened yet), this returns `nil` rather than mislabeling
    /// a 0…1 probability sample as a dollar price.
    public var priceToBeat: Decimal? {
        guard let priceWindow else {
            guard case let .loaded(points) = state else { return nil }
            let windowStart = windowEnd.addingTimeInterval(-windowInterval)
            return points.first(where: { $0.date >= windowStart })?.price ?? points.first?.price
        }
        return priceWindow.openPrice
    }

    /// The latest real dollar BTC price, for the "Current Price" header row.
    public var currentPrice: Decimal? {
        guard case let .loaded(points) = spotState else { return nil }
        return points.last?.price
    }

    /// `currentPrice - priceToBeat`, for the green/red delta shown next to "Current Price".
    public var priceDelta: Decimal? {
        guard let currentPrice, let priceToBeat else { return nil }
        return currentPrice - priceToBeat
    }

    /// Live "Up" price in cents from the book midpoint; `nil` until a book arrives.
    public var upCents: Int? {
        guard let mid = book?.midpoint else { return nil }
        return cents(mid)
    }

    /// Live "Down" price = complement of the midpoint.
    public var downCents: Int? {
        guard let mid = book?.midpoint else { return nil }
        return cents(1 - mid)
    }

    /// Countdown turns urgent (red) under a minute remaining. The red styling itself is
    /// applied in the view via a DS token — this flag only carries the intent.
    public var isCountdownUrgent: Bool { remainingSeconds > 0 && remainingSeconds < 60 }

    /// How a closed window turned out.
    public enum Settlement: Equatable {
        /// The price finished above where it started.
        case up
        /// The price finished at or below where it started.
        case down
        /// The window is closed but we never learned enough prices to say which.
        case undetermined
    }

    /// Whether this window has closed.
    ///
    /// The countdown is anchored to server time, so this flips at the same instant the
    /// market stops accepting orders rather than whenever the device thinks it should.
    /// Guarded on the clock having been anchored at all — before the first load
    /// `remainingSeconds` is still `0` and the window has not ended, it just isn't known yet.
    public var hasSettled: Bool { currentServerTime != nil && remainingSeconds == 0 }

    /// Which side won, once the window has closed.
    ///
    /// Derived from the same two dollar prices the header already shows rather than from the
    /// order book: once a window closes its book empties out, which is exactly why the screen
    /// went to "--". `priceToBeat` is the window's open and `currentPrice` its last tick, so
    /// they still tell the story after trading stops. Polymarket resolves ties as Down —
    /// the price has to strictly exceed the open for Up to win.
    public var settlement: Settlement? {
        guard hasSettled else { return nil }
        guard let currentPrice, let priceToBeat else { return .undetermined }
        return currentPrice > priceToBeat ? .up : .down
    }

    /// The current server time, computed as `serverAnchor + elapsed monotonic time`.
    /// `nil` until the anchors are set by the initial load.
    private var currentServerTime: Date? {
        guard let serverAnchor, let monoAnchor else { return nil }
        let elapsed = monoAnchor.duration(to: monoClock.now)
        return serverAnchor.addingTimeInterval(seconds(from: elapsed))
    }

    // MARK: Lifecycle

    /// Starts all the screen's concurrent work: the initial load, the book stream, and the
    /// trades poll. No-op if already running.
    public func start() {
        guard tickTask == nil, bookTask == nil else { return }
        isStopped = false
        loadTask = Task { await load() }
        bookTask = Task { [weak self] in await self?.streamBook() }
        tradesTask = Task { [weak self] in await self?.pollTrades() }
        spotTask = Task { [weak self] in await self?.streamSpotPrice() }
        windowTask = Task { [weak self] in await self?.pollPriceWindow() }
        candlesTask = Task { [weak self] in await self?.loadCandles() }
    }

    /// Cancels every running task and marks the model stopped. Call from the view's teardown.
    public func stop() {
        isStopped = true
        loadTask?.cancel(); loadTask = nil
        tickTask?.cancel(); tickTask = nil
        bookTask?.cancel(); bookTask = nil
        tradesTask?.cancel(); tradesTask = nil
        spotTask?.cancel(); spotTask = nil
        windowTask?.cancel(); windowTask = nil
        candlesTask?.cancel(); candlesTask = nil
    }

    /// Inline retry for the price-series/server-time load.
    public func retry() async {
        state = .idle
        await load()
    }

    /// Forwards an Up/Down tap to the host via the `onQuickBet` callback.
    /// - Parameter side: Which side the user tapped.
    public func quickBet(_ side: BetSide) {
        onQuickBet(side)
    }

    // MARK: Loading

    /// Loads the price series and server time in parallel, sets the countdown anchors, and
    /// starts the ticking clock. Distinguishes a cancelled load (→ `.idle`) from a real
    /// failure (→ `.failed`).
    private func load() async {
        if case .loaded = state {} else { state = .loading }
        do {
            async let historyCall = fetchHistory.execute(assetID: assetID, interval: .oneHour)
            async let timeCall = fetchServerTime.execute()
            let (points, serverNow) = try await (historyCall, timeCall)
            guard !isStopped else { return }
            serverAnchor = serverNow
            monoAnchor = monoClock.now
            refreshCountdown()
            startTicking()
            state = points.isEmpty ? .empty : .loaded(points)
        } catch {
            if isCancellation(error) {
                state = .idle
            } else {
                state = .failed(message: "Couldn't load the live market. Check your connection and try again.")
            }
        }
    }

    /// Starts a task that refreshes the countdown once per second until cancelled/stopped.
    private func startTicking() {
        guard tickTask == nil, !isStopped else { return }
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, !self.isStopped else { return }
                self.refreshCountdown()
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    /// Recomputes `remainingSeconds` and `countdown` from the server-anchored clock.
    private func refreshCountdown() {
        guard let now = currentServerTime else { return }
        remainingSeconds = max(0, Int(windowEnd.timeIntervalSince(now)))
        countdown = CountdownFormatter.string(until: windowEnd, now: now)
    }

    /// Consumes the live book stream, updating `book` on each new snapshot and appending
    /// a fresh sample to the "Chance" probability series so that chart mode stays live too
    /// (this is the only feed for `state`; there's no separate re-fetch of price history).
    private func streamBook() async {
        for await book in observeBook.execute(assetID: assetID) {
            self.book = book
            appendChancePoint(from: book)
        }
    }

    /// Appends the book's current midpoint as a new probability sample, trimming samples
    /// older than the rolling window so the series stays bounded.
    private func appendChancePoint(from book: OrderBook) {
        guard let mid = book.midpoint, case .loaded(var points) = state else { return }
        let now = currentServerTime ?? Date()
        points.append(PriceHistoryPoint(date: now, price: mid))
        let cutoff = now.addingTimeInterval(-windowInterval)
        points.removeAll { $0.date < cutoff }
        state = .loaded(points)
    }

    /// Polls recent trades every ~5 seconds, keeping the last good list on transient errors.
    private func pollTrades() async {
        while !Task.isCancelled {
            do {
                let trades = try await fetchRecentTrades.execute(eventID: eventID, limit: 10)
                if !Task.isCancelled { recentTrades = trades }
            } catch {
                if isCancellation(error) { return }
                // Non-fatal for the ticker: keep the last good list and retry next tick.
            }
            try? await Task.sleep(nanoseconds: 5_000_000_000)
        }
    }

    /// Consumes the live dollar spot-price stream, updating `spotState` as the series grows.
    /// The use case seeds with the REST history (so the chart isn't blank on entry) and then
    /// folds live RTDS ticks in, so `currentPrice` follows the market in real time instead of
    /// lagging up to 5s behind a poll.
    private func streamSpotPrice() async {
        let eventStart = windowEnd.addingTimeInterval(-windowInterval)
        for await points in observeSpotPrice.execute(
            symbol: symbol, eventStart: eventStart, eventEnd: windowEnd
        ) {
            if Task.isCancelled { return }
            spotState = points.isEmpty ? .empty : .loaded(points)
            // Keep the forming candle live. Only once the seed page exists: folding into
            // an empty series would create a lone tick-candle that `loadCandles` then
            // clobbers — before the seed, the bucketing fallback covers display anyway.
            if !candleSeries.isEmpty, let tick = points.last {
                candleSeries = CandleAggregator.folding(candleSeries, with: tick, interval: candleInterval.seconds)
            }
        }
    }

    /// How many candle pages the seed load fetches (30 candles each), giving the chart
    /// several hours of scroll-back history up front. History depth is fixed at load
    /// rather than paged in as the user scrolls: driving pagination off the chart's
    /// scroll-position binding proved unreliable — Swift Charts desyncs that binding
    /// from its real viewport under live-tick updates, teleporting the view when a page
    /// was prepended (the "glitching" candle chart).
    public static let seedCandlePages = 3

    /// Loads the newest candle-history page, then pages backwards until the history
    /// budget (`seedCandlePages`) is spent or the feed runs short. Any ticks that
    /// arrived while the fetch was in flight re-fold on the next stream emission.
    private func loadCandles() async {
        do {
            let page = try await fetchCandles.execute(symbol: symbol, interval: candleInterval)
            guard !Task.isCancelled, !isStopped else { return }
            candleSeries = page
            hasMoreCandles = page.count >= FetchCryptoCandlesUseCase.pageSize
        } catch {
            // Non-fatal: `candles` falls back to bucketing the window-scoped spot series,
            // which still shows the current forming candle.
            return
        }
        for _ in 1..<Self.seedCandlePages {
            guard hasMoreCandles, !Task.isCancelled, !isStopped else { return }
            await loadMoreCandles()
        }
    }

    /// Pages one screen of older candles onto the front of the series. A short page
    /// marks the end of history; a failed page keeps `hasMoreCandles` so a later call
    /// can retry.
    public func loadMoreCandles() async {
        guard hasMoreCandles, !isLoadingMoreCandles, let oldest = candleSeries.first else { return }
        isLoadingMoreCandles = true
        defer { isLoadingMoreCandles = false }
        do {
            let page = try await fetchCandles.execute(
                symbol: symbol, interval: candleInterval, before: oldest.start
            )
            guard !Task.isCancelled, !isStopped else { return }
            // The cursor is exclusive server-side, but never trust it blindly: a candle
            // at/after the oldest we already have would corrupt the series' ordering.
            candleSeries = page.filter { $0.start < oldest.start } + candleSeries
            hasMoreCandles = page.count >= FetchCryptoCandlesUseCase.pageSize
        } catch {
            // Non-fatal: keep hasMoreCandles as-is so a later call can retry.
        }
    }

    /// Polls the window's dollar open/close snapshot (the "price to beat") every ~5 seconds.
    /// Unlike the spot price, this isn't carried on the live tick feed — it's a checkpointed
    /// open/close derived server-side — so, like `pollTrades`, it stays a timer poll that
    /// keeps the last good value on transient errors.
    private func pollPriceWindow() async {
        let eventStart = windowEnd.addingTimeInterval(-windowInterval)
        while !Task.isCancelled {
            do {
                let window = try await fetchPriceWindow.execute(
                    symbol: symbol, eventStart: eventStart, eventEnd: windowEnd
                )
                if !Task.isCancelled { priceWindow = window }
            } catch {
                if isCancellation(error) { return }
                // Non-fatal: keep the last good window and retry next tick.
            }
            try? await Task.sleep(nanoseconds: 5_000_000_000)
        }
    }

    // MARK: Helpers

    /// Converts a 0…1 probability into a whole-cent price (0…100), clamping out-of-range
    /// inputs first.
    private func cents(_ fraction: Decimal) -> Int {
        let clamped = min(1, max(0, fraction))
        return Int((NSDecimalNumber(decimal: clamped).doubleValue * 100).rounded())
    }

    /// Converts a `Duration` into a fractional number of seconds.
    private func seconds(from duration: Duration) -> Double {
        let c = duration.components
        return Double(c.seconds) + Double(c.attoseconds) / 1e18
    }

    /// A cancelled task during teardown is not a failure — mirror the SocialStrip pattern.
    private func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        if (error as? URLError)?.code == .cancelled { return true }
        return Task.isCancelled
    }
}
