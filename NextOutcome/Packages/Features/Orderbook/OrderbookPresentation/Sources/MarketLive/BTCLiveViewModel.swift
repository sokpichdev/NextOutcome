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
    public enum ChartMode: Sendable { case line, candles }
    public enum BetSide: Sendable { case up, down }

    /// The price series backing both chart modes and the price-to-beat line.
    public private(set) var state: LoadState<[PriceHistoryPoint]> = .idle
    public var chartMode: ChartMode = .candles
    public private(set) var countdown: String = "--:--"
    /// Seconds left until the window closes, per the server-anchored clock.
    public private(set) var remainingSeconds: Int = 0
    public private(set) var recentTrades: [RecentTrade] = []
    public private(set) var book: OrderBook?

    /// Candle interval within the window (seconds).
    public let candleInterval: TimeInterval = 60
    /// The rolling window used to pick the price-to-beat (5 minutes).
    public let windowInterval: TimeInterval = 300

    private let assetID: String
    private let eventID: String
    private let windowEnd: Date
    private let fetchHistory: FetchPriceHistoryUseCase
    private let fetchServerTime: FetchServerTimeUseCase
    private let fetchRecentTrades: FetchRecentTradesUseCase
    private let observeBook: ObserveOrderBookUseCase
    private let onQuickBet: @MainActor (BetSide) -> Void

    private var tickTask: Task<Void, Never>?
    private var bookTask: Task<Void, Never>?
    private var tradesTask: Task<Void, Never>?
    private var loadTask: Task<Void, Never>?
    /// Set once `stop()` runs; guards against a late-completing `load()` resurrecting
    /// the countdown ticker (or spawning other work) after teardown.
    private(set) var isStopped = false

    private let monoClock = ContinuousClock()
    private var serverAnchor: Date?
    private var monoAnchor: ContinuousClock.Instant?

    public init(
        assetID: String,
        eventID: String,
        windowEnd: Date,
        fetchHistory: FetchPriceHistoryUseCase,
        fetchServerTime: FetchServerTimeUseCase,
        fetchRecentTrades: FetchRecentTradesUseCase,
        observeBook: ObserveOrderBookUseCase,
        onQuickBet: @escaping @MainActor (BetSide) -> Void
    ) {
        self.assetID = assetID
        self.eventID = eventID
        self.windowEnd = windowEnd
        self.fetchHistory = fetchHistory
        self.fetchServerTime = fetchServerTime
        self.fetchRecentTrades = fetchRecentTrades
        self.observeBook = observeBook
        self.onQuickBet = onQuickBet
    }

    // MARK: Derived

    /// OHLC candles bucketed from the loaded price series.
    public var candles: [Candle] {
        guard case let .loaded(points) = state else { return [] }
        return CandleAggregator.candles(from: points, interval: candleInterval)
    }

    /// Price to beat = the first sample at or after the window's fixed open time
    /// (`windowEnd - windowInterval`). Anchored to the window open — not to `now` —
    /// so the selected point never drifts as the countdown advances.
    public var priceToBeat: Decimal? {
        guard case let .loaded(points) = state else { return nil }
        let windowStart = windowEnd.addingTimeInterval(-windowInterval)
        return points.first(where: { $0.date >= windowStart })?.price ?? points.first?.price
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

    private var currentServerTime: Date? {
        guard let serverAnchor, let monoAnchor else { return nil }
        let elapsed = monoAnchor.duration(to: monoClock.now)
        return serverAnchor.addingTimeInterval(seconds(from: elapsed))
    }

    // MARK: Lifecycle

    public func start() {
        guard tickTask == nil, bookTask == nil else { return }
        isStopped = false
        loadTask = Task { await load() }
        bookTask = Task { [weak self] in await self?.streamBook() }
        tradesTask = Task { [weak self] in await self?.pollTrades() }
    }

    public func stop() {
        isStopped = true
        loadTask?.cancel(); loadTask = nil
        tickTask?.cancel(); tickTask = nil
        bookTask?.cancel(); bookTask = nil
        tradesTask?.cancel(); tradesTask = nil
    }

    /// Inline retry for the price-series/server-time load.
    public func retry() async {
        state = .idle
        await load()
    }

    public func quickBet(_ side: BetSide) {
        onQuickBet(side)
    }

    // MARK: Loading

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

    private func refreshCountdown() {
        guard let now = currentServerTime else { return }
        remainingSeconds = max(0, Int(windowEnd.timeIntervalSince(now)))
        countdown = CountdownFormatter.string(until: windowEnd, now: now)
    }

    private func streamBook() async {
        for await book in observeBook.execute(assetID: assetID) {
            self.book = book
        }
    }

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

    // MARK: Helpers

    private func cents(_ fraction: Decimal) -> Int {
        let clamped = min(1, max(0, fraction))
        return Int((NSDecimalNumber(decimal: clamped).doubleValue * 100).rounded())
    }

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
