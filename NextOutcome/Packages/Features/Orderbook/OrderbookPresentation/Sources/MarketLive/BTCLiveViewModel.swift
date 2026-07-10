//
//  BTCLiveViewModel.swift
//  NextOutcome
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
    /// modes, refreshed by polling (see `pollSpotPrice`).
    public private(set) var spotState: LoadState<[CryptoSpotPricePoint]> = .idle
    /// The window's dollar open/close snapshot — the source of `priceToBeat`.
    public private(set) var priceWindow: CryptoPriceWindow?
    /// The chart mode the user has selected.
    public var chartMode: ChartMode = .price
    /// The formatted countdown string (e.g. "3:47") shown in the header.
    public private(set) var countdown: String = "--:--"
    /// Seconds left until the window closes, per the server-anchored clock.
    public private(set) var remainingSeconds: Int = 0
    /// The recent-trades ticker contents, refreshed by polling.
    public private(set) var recentTrades: [RecentTrade] = []
    /// The latest order book, used for the live Up/Down cents.
    public private(set) var book: OrderBook?

    /// Candle interval within the window (seconds).
    public let candleInterval: TimeInterval = 60
    /// The rolling window used to pick the price-to-beat (5 minutes).
    public let windowInterval: TimeInterval = 300

    /// The "Up" outcome token being charted/traded.
    private let assetID: String
    /// The event id used by the recent-trades poll.
    private let eventID: String
    /// When the current 5-minute window closes.
    private let windowEnd: Date
    /// Use case that loads the price series.
    private let fetchHistory: FetchPriceHistoryUseCase
    /// Use case that fetches authoritative server time (fetched once).
    private let fetchServerTime: FetchServerTimeUseCase
    /// Use case that polls recent trades.
    private let fetchRecentTrades: FetchRecentTradesUseCase
    /// Use case that streams the live book.
    private let observeBook: ObserveOrderBookUseCase
    /// Use case that polls the real dollar spot-price series.
    private let fetchSpotPriceHistory: FetchCryptoSpotPriceHistoryUseCase
    /// Use case that polls the window's dollar open/close snapshot.
    private let fetchPriceWindow: FetchCryptoPriceWindowUseCase
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
    /// Polls the real dollar spot-price series on a timer.
    private var spotTask: Task<Void, Never>?
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
    ///   - fetchHistory: Loads the price series.
    ///   - fetchServerTime: Fetches authoritative server time (once).
    ///   - fetchRecentTrades: Polls recent trades.
    ///   - observeBook: Streams the live book.
    ///   - fetchSpotPriceHistory: Polls the real dollar spot-price series.
    ///   - fetchPriceWindow: Polls the window's dollar open/close snapshot.
    ///   - onQuickBet: Called when the user taps Up/Down.
    public init(
        assetID: String,
        eventID: String,
        windowEnd: Date,
        fetchHistory: FetchPriceHistoryUseCase,
        fetchServerTime: FetchServerTimeUseCase,
        fetchRecentTrades: FetchRecentTradesUseCase,
        observeBook: ObserveOrderBookUseCase,
        fetchSpotPriceHistory: FetchCryptoSpotPriceHistoryUseCase,
        fetchPriceWindow: FetchCryptoPriceWindowUseCase,
        onQuickBet: @escaping @MainActor (BetSide) -> Void
    ) {
        self.assetID = assetID
        self.eventID = eventID
        self.windowEnd = windowEnd
        self.fetchHistory = fetchHistory
        self.fetchServerTime = fetchServerTime
        self.fetchRecentTrades = fetchRecentTrades
        self.observeBook = observeBook
        self.fetchSpotPriceHistory = fetchSpotPriceHistory
        self.fetchPriceWindow = fetchPriceWindow
        self.onQuickBet = onQuickBet
    }

    // MARK: Derived

    /// Dollar OHLC candles bucketed from the loaded spot-price series (the "Candles"
    /// chart mode — matches web, which has no probability-candle view).
    public var candles: [Candle] {
        guard case let .loaded(points) = spotState else { return [] }
        let pricePoints = points.map { PricePoint(date: $0.date, price: $0.price) }
        return CandleAggregator.candles(from: pricePoints, interval: candleInterval)
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
        spotTask = Task { [weak self] in await self?.pollSpotPrice() }
    }

    /// Cancels every running task and marks the model stopped. Call from the view's teardown.
    public func stop() {
        isStopped = true
        loadTask?.cancel(); loadTask = nil
        tickTask?.cancel(); tickTask = nil
        bookTask?.cancel(); bookTask = nil
        tradesTask?.cancel(); tradesTask = nil
        spotTask?.cancel(); spotTask = nil
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

    /// Polls the real dollar spot-price series (and the window's open/close snapshot)
    /// every ~5 seconds. There's no WebSocket source for this data, so — like
    /// `pollTrades` — it's refetched on a timer, keeping the last good state on
    /// transient errors.
    private func pollSpotPrice() async {
        let eventStart = windowEnd.addingTimeInterval(-windowInterval)
        while !Task.isCancelled {
            do {
                async let historyCall = fetchSpotPriceHistory.execute(
                    symbol: "BTC", eventStart: eventStart, eventEnd: windowEnd
                )
                async let windowCall = fetchPriceWindow.execute(
                    symbol: "BTC", eventStart: eventStart, eventEnd: windowEnd
                )
                let (points, window) = try await (historyCall, windowCall)
                if !Task.isCancelled {
                    spotState = points.isEmpty ? .empty : .loaded(points)
                    priceWindow = window
                }
            } catch {
                if isCancellation(error) { return }
                // Non-fatal: keep the last good series/window and retry next tick.
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
