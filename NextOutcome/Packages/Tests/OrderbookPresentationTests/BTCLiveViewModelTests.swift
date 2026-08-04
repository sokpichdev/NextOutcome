//
//  BTCLiveViewModelTests.swift
//  NextOutcome
//
//  Created by Sok Pich on 03/07/2026.
//

import XCTest
@testable import OrderbookPresentation
import OrderbookDomain
import SharedDomain
import Foundation

/// Deterministic gate used to hold a fake repository call open until the test explicitly
/// releases it, so races (e.g. teardown vs. a late-completing load) don't depend on
/// sleep timing. Mirrors the pattern used in EventChartViewModelTests.
private actor Gate {
    private var isReleased = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        if isReleased { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func release() {
        isReleased = true
        waiters.forEach { $0.resume() }
        waiters.removeAll()
    }
}

/// Minimal fake `OrderbookRepository`. `historyGate`, when set, blocks `priceHistory`
/// until released, so tests can control exactly when `load()` completes.
private final class FakeOrderbookRepository: OrderbookRepository, @unchecked Sendable {
    var points: [PriceHistoryPoint] = []
    var serverNow: Date = Date()
    var historyGate: Gate?

    func book(assetID: String) async throws -> OrderBook {
        OrderBook(assetID: assetID)
    }

    func priceHistory(assetID: String, interval: PriceHistoryInterval) async throws -> [PriceHistoryPoint] {
        if let historyGate {
            await historyGate.wait()
        }
        return points
    }

    func serverTime() async throws -> Date {
        serverNow
    }

    func recentTrades(eventID: String, limit: Int) async throws -> [RecentTrade] {
        []
    }
}

/// No-op streaming source: never yields, so `streamBook()` just idles until cancelled.
private struct FakeMarketStreaming: MarketStreaming {
    func events(assetID: String) -> AsyncStream<OrderBookEvent> {
        AsyncStream { _ in }
    }
}

/// Preset crypto-price streamer: emits the given live points (in order) then finishes, so
/// tests can assert the view model folds live socket ticks into `spotState`/`currentPrice`.
private struct FakeCryptoSpotPriceStreaming: CryptoSpotPriceStreaming {
    var points: [CryptoSpotPricePoint] = []
    func prices(symbol: String) -> AsyncStream<CryptoSpotPricePoint> {
        AsyncStream { continuation in
            points.forEach { continuation.yield($0) }
            continuation.finish()
        }
    }
}

/// Minimal fake `CryptoSpotPriceRepository`. Returns whatever's currently set on
/// `points`/`window`, so a test can mutate them between polls to simulate a live update.
///
/// The view model calls this from several concurrently running tasks (spot seed, window
/// poll, candle pages), so every touch of the mutable state goes through `lock` — the
/// `@unchecked Sendable` is otherwise a lie that segfaults the suite intermittently.
private final class FakeCryptoSpotPriceRepository: CryptoSpotPriceRepository, @unchecked Sendable {
    private let lock = NSLock()

    private var _points: [CryptoSpotPricePoint] = []
    var points: [CryptoSpotPricePoint] {
        get { lock.withLock { _points } }
        set { lock.withLock { _points = newValue } }
    }

    private var _window = CryptoPriceWindow(
        openPrice: 0, closePrice: nil, timestamp: Date(), completed: false
    )
    var window: CryptoPriceWindow {
        get { lock.withLock { _window } }
        set { lock.withLock { _window = newValue } }
    }

    /// The `symbol` argument each call was actually invoked with, so tests can assert
    /// the view model doesn't hardcode "BTC" for a non-Bitcoin market.
    private var _requestedSymbols: [String] = []
    var requestedSymbols: [String] { lock.withLock { _requestedSymbols } }

    /// Successive pages returned by `candles` (first call gets the first page, and so
    /// on); once exhausted, further calls return `[]`. Defaults to no pages, so tests
    /// that don't care about candle history exercise the bucketing fallback.
    private var _candlePages: [[Candle]] = []
    var candlePages: [[Candle]] {
        get { lock.withLock { _candlePages } }
        set { lock.withLock { _candlePages = newValue } }
    }

    /// The `before` cursor of each `candles` call, so pagination tests can assert the
    /// view model walks backwards from its oldest loaded candle.
    private var _candleBeforeCursors: [Date?] = []
    var candleBeforeCursors: [Date?] { lock.withLock { _candleBeforeCursors } }

    func spotPriceHistory(symbol: String, eventStart: Date, eventEnd: Date) async throws -> [CryptoSpotPricePoint] {
        lock.withLock {
            _requestedSymbols.append(symbol)
            return _points
        }
    }

    func priceWindow(symbol: String, eventStart: Date, eventEnd: Date) async throws -> CryptoPriceWindow {
        lock.withLock {
            _requestedSymbols.append(symbol)
            return _window
        }
    }

    func candles(symbol: String, interval: CandleInterval, before: Date?) async throws -> [Candle] {
        lock.withLock {
            _requestedSymbols.append(symbol)
            _candleBeforeCursors.append(before)
            guard !_candlePages.isEmpty else { return [] }
            return _candlePages.removeFirst()
        }
    }
}

final class BTCLiveViewModelTests: XCTestCase {
    @MainActor
    private func makeVM(
        repository: FakeOrderbookRepository,
        windowEnd: Date,
        symbol: String = "BTC",
        spotRepository: FakeCryptoSpotPriceRepository = FakeCryptoSpotPriceRepository(),
        spotStreamer: FakeCryptoSpotPriceStreaming = FakeCryptoSpotPriceStreaming()
    ) -> BTCLiveViewModel {
        BTCLiveViewModel(
            assetID: "asset-1",
            eventID: "event-1",
            windowEnd: windowEnd,
            symbol: symbol,
            fetchHistory: FetchPriceHistoryUseCase(repository: repository),
            fetchServerTime: FetchServerTimeUseCase(repository: repository),
            fetchRecentTrades: FetchRecentTradesUseCase(repository: repository),
            observeBook: ObserveOrderBookUseCase(repository: repository, stream: FakeMarketStreaming()),
            observeSpotPrice: ObserveCryptoSpotPriceUseCase(repository: spotRepository, stream: spotStreamer),
            fetchPriceWindow: FetchCryptoPriceWindowUseCase(repository: spotRepository),
            fetchCandles: FetchCryptoCandlesUseCase(repository: spotRepository),
            onQuickBet: { _ in }
        )
    }

    /// A page of `count` flat 5-minute candles ending with the bucket that starts at
    /// `lastStart`, oldest first.
    private func candlePage(endingAt lastStart: Date, count: Int, price: Decimal = 63_000) -> [Candle] {
        (0..<count).map { offset in
            let start = lastStart.addingTimeInterval(-300 * Double(count - 1 - offset))
            return Candle(open: price, high: price, low: price, close: price, start: start)
        }
    }

    /// Regression test for the sliding-window bug: `priceToBeat` must be pinned to the
    /// window's fixed open time (`windowEnd - windowInterval`), not to the server-time
    /// anchor (`now`). We drive the VM's notion of "now" via the fake repository's
    /// `serverTime()` seam — first close to window open, then re-anchored far later
    /// (well past every sample-point boundary, crossing the 30s/90s spacing). Under the
    /// old buggy implementation (`now.addingTimeInterval(-windowInterval)`), advancing
    /// `now` by 90s+ would slide the window forward and pick a later sample; the fix
    /// derives `windowStart` from the fixed `windowEnd` alone, so `priceToBeat` must be
    /// bit-for-bit identical across both anchors.
    @MainActor
    func test_priceToBeat_staysConstant_asServerTimeAdvancesWithinWindow() async {
        let windowEnd = Date(timeIntervalSince1970: 1_000_000)
        let windowOpen = windowEnd.addingTimeInterval(-300) // windowInterval = 300s

        let repository = FakeOrderbookRepository()
        repository.points = [
            PriceHistoryPoint(date: windowOpen.addingTimeInterval(-120), price: 0.10), // before window
            PriceHistoryPoint(date: windowOpen, price: 0.42),                          // window open — expected pick
            PriceHistoryPoint(date: windowOpen.addingTimeInterval(30), price: 0.55),
            PriceHistoryPoint(date: windowOpen.addingTimeInterval(90), price: 0.61),
        ]
        repository.serverNow = windowOpen.addingTimeInterval(10)

        let vm = makeVM(repository: repository, windowEnd: windowEnd)
        await vm.retry() // drives load() synchronously to completion (awaited)

        let first = vm.priceToBeat
        XCTAssertEqual(first, 0.42)

        // Re-anchor the server-time seam far forward within the window (past the 30s and
        // 90s sample points) and re-load. A sliding window would now pick 0.55 or 0.61;
        // the fixed-anchor implementation must still pick 0.42.
        repository.serverNow = windowOpen.addingTimeInterval(180)
        await vm.retry()
        XCTAssertEqual(
            vm.priceToBeat, 0.42,
            "priceToBeat must stay pinned to the window open even after the server-time anchor advances 180s"
        )

        // Push the anchor all the way to windowEnd itself — the most aggressive case for
        // a sliding window (it would pick the very last sample, 0.61).
        repository.serverNow = windowEnd
        await vm.retry()
        XCTAssertEqual(
            vm.priceToBeat, 0.42,
            "priceToBeat must stay pinned to the window open even when the server-time anchor reaches windowEnd"
        )
        XCTAssertEqual(vm.priceToBeat, first)
    }

    /// Regression test for the teardown leak: calling `stop()` while the initial
    /// `load()` is still in flight must prevent that load from resurrecting the
    /// countdown ticker once it resolves. We gate `priceHistory` open, start the VM,
    /// stop it before the gate is released, then release the gate and verify the VM
    /// stays torn down (no ticking resumes, `isStopped` remains true).
    @MainActor
    func test_stopBeforeLoadCompletes_preventsTickerFromStartingAfterTeardown() async {
        let windowEnd = Date().addingTimeInterval(300)
        let repository = FakeOrderbookRepository()
        repository.points = [PriceHistoryPoint(date: Date(), price: 0.5)]
        repository.serverNow = Date()
        let gate = Gate()
        repository.historyGate = gate

        let vm = makeVM(repository: repository, windowEnd: windowEnd)

        vm.start()
        // Let the unstructured load task actually start and block on the gate.
        for _ in 0..<10 { await Task.yield() }

        vm.stop()
        XCTAssertTrue(vm.isStopped)
        let countdownAtStop = vm.countdown

        // Now let the late load resolve. Per the fix, it must observe `isStopped` and
        // bail out before calling `startTicking()`.
        await gate.release()
        for _ in 0..<20 { await Task.yield() }

        // The VM must remain torn down: still stopped, and the countdown must not have
        // been mutated by a resurrected ticker (it never got the chance to start
        // ticking, so refreshCountdown never re-ran after teardown).
        XCTAssertTrue(vm.isStopped, "stop() state must not be undone by a late-completing load()")
        XCTAssertEqual(vm.countdown, countdownAtStop, "no ticker should have resumed updating the countdown after stop()")
    }

    /// `start()` must poll the spot-price feed and populate `spotState`/`currentPrice`
    /// from it — there's no other way this data reaches the VM (no WebSocket source).
    @MainActor
    func test_start_pollsSpotPrice_andPopulatesCurrentPrice() async {
        let windowEnd = Date().addingTimeInterval(300)
        let repository = FakeOrderbookRepository()
        repository.points = [PriceHistoryPoint(date: Date(), price: 0.5)]

        let spotRepository = FakeCryptoSpotPriceRepository()
        spotRepository.points = [
            CryptoSpotPricePoint(date: Date().addingTimeInterval(-60), price: 63_945.94),
            CryptoSpotPricePoint(date: Date(), price: 63_961.25)
        ]
        spotRepository.window = CryptoPriceWindow(
            openPrice: 63_945.94, closePrice: nil, timestamp: Date(), completed: false
        )

        let vm = makeVM(repository: repository, windowEnd: windowEnd, spotRepository: spotRepository)
        vm.start()
        for _ in 0..<20 { await Task.yield() }
        vm.stop()

        XCTAssertEqual(vm.currentPrice, 63_961.25)
        XCTAssertEqual(vm.priceToBeat, 63_945.94, "priceToBeat must prefer the polled dollar window over the probability fallback")
        XCTAssertEqual(vm.priceDelta, 63_961.25 - 63_945.94)
    }

    /// `currentPrice` must follow the live RTDS socket tick, not just the REST seed — this is
    /// the whole point of moving off the 5-second poll. We seed the REST history with one
    /// stale sample, then have the fake streamer emit a newer tick; `currentPrice` must be the
    /// streamed value.
    @MainActor
    func test_start_streamsLiveSpotPrice_updatesCurrentPriceBeyondTheSeed() async {
        let windowEnd = Date().addingTimeInterval(300)
        let repository = FakeOrderbookRepository()
        repository.points = [PriceHistoryPoint(date: Date(), price: 0.5)]

        let spotRepository = FakeCryptoSpotPriceRepository()
        spotRepository.points = [CryptoSpotPricePoint(date: Date().addingTimeInterval(-60), price: 63_000)]
        let streamer = FakeCryptoSpotPriceStreaming(points: [
            CryptoSpotPricePoint(date: Date(), price: 63_412.75)
        ])

        let vm = makeVM(
            repository: repository, windowEnd: windowEnd,
            spotRepository: spotRepository, spotStreamer: streamer
        )
        vm.start()
        for _ in 0..<50 { await Task.yield() }
        vm.stop()

        XCTAssertEqual(
            vm.currentPrice, 63_412.75,
            "currentPrice must reflect the live streamed tick, not just the REST seed"
        )
    }

    /// `.candles` mode builds from the dollar spot series, not the 0…1 probability
    /// series — a regression guard for the "repurposed to dollars" change.
    @MainActor
    func test_candles_bucketDollarSpotPrices_notProbability() async {
        let windowEnd = Date(timeIntervalSince1970: 1_000_000)
        let repository = FakeOrderbookRepository()
        repository.points = [PriceHistoryPoint(date: windowEnd.addingTimeInterval(-60), price: 0.5)]

        let spotRepository = FakeCryptoSpotPriceRepository()
        let bucketStart = Date(timeIntervalSince1970: 0)
        spotRepository.points = [
            CryptoSpotPricePoint(date: bucketStart, price: 63_900),
            CryptoSpotPricePoint(date: bucketStart.addingTimeInterval(30), price: 64_100)
        ]

        let vm = makeVM(repository: repository, windowEnd: windowEnd, spotRepository: spotRepository)
        vm.start()
        for _ in 0..<20 { await Task.yield() }
        vm.stop()

        let candles = vm.candles
        XCTAssertEqual(candles.count, 1)
        XCTAssertEqual(candles.first?.open, 63_900)
        XCTAssertEqual(candles.first?.close, 64_100)
        XCTAssertEqual(candles.first?.high, 64_100)
    }

    /// Regression test: `spotPriceHistory` only ever returns ~1 sample per minute for
    /// this round (a checkpointed oracle price, not tick data). Bucketing those by a
    /// fixed time interval put at most one sample per bucket, so every candle degenerated
    /// to a flat dot with no visible body/wick ("candles not doing anything"). Each
    /// consecutive pair of real samples must become its own candle instead, so N samples
    /// produce N-1 candles, each reflecting an actual price move.
    @MainActor
    func test_candles_oneMinuteSpacedSamples_produceNonDegenerateCandles() async {
        let windowEnd = Date(timeIntervalSince1970: 1_000_000)
        let repository = FakeOrderbookRepository()
        repository.points = [PriceHistoryPoint(date: windowEnd.addingTimeInterval(-60), price: 0.5)]

        let spotRepository = FakeCryptoSpotPriceRepository()
        let start = Date(timeIntervalSince1970: 0)
        spotRepository.points = [
            CryptoSpotPricePoint(date: start, price: 63_900),
            CryptoSpotPricePoint(date: start.addingTimeInterval(60), price: 63_950),
            CryptoSpotPricePoint(date: start.addingTimeInterval(120), price: 63_890),
            CryptoSpotPricePoint(date: start.addingTimeInterval(180), price: 64_010)
        ]

        let vm = makeVM(repository: repository, windowEnd: windowEnd, spotRepository: spotRepository)
        vm.start()
        for _ in 0..<20 { await Task.yield() }
        vm.stop()

        // Superseded expectation. This used to assert 3 candles from 4 samples, because
        // candles were one-per-consecutive-pair — chosen to avoid the flat dots that a 60s
        // bucket produced on this ~1-sample-per-minute feed. That model was wrong: a candle
        // is the betting window itself, so four samples inside one 5-minute window are one
        // candle, forming in place. It still spans a real move (the wick carries the extremes
        // across the whole window), which is what the old assertion was really protecting.
        let candles = vm.candles
        XCTAssertEqual(candles.count, 1, "four samples inside one 5-minute window are one candle")
        XCTAssertNotEqual(candles[0].high, candles[0].low, "the candle must still span a real price move")
        XCTAssertEqual(candles[0].open, 63_900, "opens at the window's first price")
        XCTAssertEqual(candles[0].close, 64_010, "closes at the latest price")
        XCTAssertEqual(candles[0].high, 64_010)
        XCTAssertEqual(candles[0].low, 63_890)
    }

    /// Regression test: this screen opens for any Up/Down crypto market (BTC, ETH, SOL,
    /// …), not just Bitcoin — `pollSpotPrice` must query the feed with the event's actual
    /// asset symbol, not a hardcoded "BTC". Without this, an Ethereum round's spot-price
    /// requests silently ask the server for BTC data, which never matches, so the chart
    /// (and "Price to beat"/"Current Price") stay empty forever.
    @MainActor
    func test_pollSpotPrice_usesTheProvidedSymbol_notHardcodedBTC() async {
        let windowEnd = Date().addingTimeInterval(300)
        let repository = FakeOrderbookRepository()
        repository.points = [PriceHistoryPoint(date: Date(), price: 0.5)]

        let spotRepository = FakeCryptoSpotPriceRepository()
        spotRepository.points = [CryptoSpotPricePoint(date: Date(), price: 3_400)]

        let vm = makeVM(repository: repository, windowEnd: windowEnd, symbol: "ETH", spotRepository: spotRepository)
        vm.start()
        for _ in 0..<20 { await Task.yield() }
        vm.stop()

        XCTAssertFalse(spotRepository.requestedSymbols.isEmpty, "expected at least one poll to have fired")
        XCTAssertTrue(
            spotRepository.requestedSymbols.allSatisfy { $0 == "ETH" },
            "expected every spot-price request to use the event's own symbol (ETH), got \(spotRepository.requestedSymbols)"
        )
    }

    // MARK: - Real candle history (chainlink-candles feed)

    /// When the candle feed has history, `candles` must be that history — not candles
    /// bucketed out of the window-scoped spot series, which can only ever produce the
    /// single current window (the "one lone candle" bug).
    @MainActor
    func test_candles_preferServerCandleHistory_overWindowScopedBucketing() async {
        let windowEnd = Date(timeIntervalSince1970: 999_900)
        let repository = FakeOrderbookRepository()
        repository.points = [PriceHistoryPoint(date: windowEnd.addingTimeInterval(-60), price: 0.5)]

        let spotRepository = FakeCryptoSpotPriceRepository()
        // The spot seed's last sample lands inside the forming candle's bucket, so it
        // legitimately folds into that candle whenever the candle page loads first. Keep
        // its price equal to the candle's so the fold is value-neutral and the assertion
        // doesn't depend on task ordering.
        spotRepository.points = [CryptoSpotPricePoint(date: windowEnd.addingTimeInterval(-120), price: 63_000)]
        let history = candlePage(endingAt: Date(timeIntervalSince1970: 999_600), count: 3)
        spotRepository.candlePages = [history]

        let vm = makeVM(repository: repository, windowEnd: windowEnd, spotRepository: spotRepository)
        vm.start()
        for _ in 0..<50 { await Task.yield() }
        vm.stop()

        XCTAssertEqual(vm.candles, history, "candles must come from the candle feed, not window bucketing")
    }

    /// A live tick inside the newest candle's bucket must update that forming candle
    /// (close/high/low), keeping the candle count stable.
    @MainActor
    func test_liveTick_foldsIntoFormingCandle() async {
        let windowEnd = Date(timeIntervalSince1970: 999_900)
        let repository = FakeOrderbookRepository()
        repository.points = [PriceHistoryPoint(date: windowEnd.addingTimeInterval(-60), price: 0.5)]

        let spotRepository = FakeCryptoSpotPriceRepository()
        let lastStart = Date(timeIntervalSince1970: 999_600)
        spotRepository.candlePages = [candlePage(endingAt: lastStart, count: 3)]
        let streamer = FakeCryptoSpotPriceStreaming(points: [
            CryptoSpotPricePoint(date: lastStart.addingTimeInterval(30), price: 64_250)
        ])

        let vm = makeVM(
            repository: repository, windowEnd: windowEnd,
            spotRepository: spotRepository, spotStreamer: streamer
        )
        vm.start()
        for _ in 0..<50 { await Task.yield() }
        vm.stop()

        XCTAssertEqual(vm.candles.count, 3, "a tick inside the forming bucket must not add a candle")
        XCTAssertEqual(vm.candles.last?.close, 64_250)
        XCTAssertEqual(vm.candles.last?.high, 64_250)
        XCTAssertEqual(vm.candles.last?.open, 63_000, "the forming candle's open must not move")
    }

    /// A live tick past the newest candle's bucket boundary must roll the chart into a
    /// new forming candle.
    @MainActor
    func test_liveTick_pastBucketBoundary_startsNewCandle() async {
        let windowEnd = Date(timeIntervalSince1970: 999_900)
        let repository = FakeOrderbookRepository()
        repository.points = [PriceHistoryPoint(date: windowEnd.addingTimeInterval(-60), price: 0.5)]

        let spotRepository = FakeCryptoSpotPriceRepository()
        let lastStart = Date(timeIntervalSince1970: 999_600)
        spotRepository.candlePages = [candlePage(endingAt: lastStart, count: 3)]
        let streamer = FakeCryptoSpotPriceStreaming(points: [
            CryptoSpotPricePoint(date: lastStart.addingTimeInterval(310), price: 63_700)
        ])

        let vm = makeVM(
            repository: repository, windowEnd: windowEnd,
            spotRepository: spotRepository, spotStreamer: streamer
        )
        vm.start()
        for _ in 0..<50 { await Task.yield() }
        vm.stop()

        XCTAssertEqual(vm.candles.count, 4, "a tick past the boundary must start the next candle")
        XCTAssertEqual(vm.candles.last?.start, lastStart.addingTimeInterval(300))
        XCTAssertEqual(vm.candles.last?.open, 63_700)
    }

    /// The seed load must page backwards automatically (up to `seedCandlePages` pages,
    /// exclusive `before` cursor from the oldest loaded candle), prepending older pages
    /// and flipping `hasMoreCandles` off once the server returns a short page. History
    /// depth is fixed up front because scroll-driven pagination proved unreliable (the
    /// chart-scroll binding desyncs under live ticks and teleported the viewport).
    @MainActor
    func test_seed_pagesBackwardsAutomatically_andStopsOnShortPage() async {
        let windowEnd = Date(timeIntervalSince1970: 999_900)
        let repository = FakeOrderbookRepository()
        repository.points = [PriceHistoryPoint(date: windowEnd.addingTimeInterval(-60), price: 0.5)]

        let spotRepository = FakeCryptoSpotPriceRepository()
        let firstPage = candlePage(endingAt: Date(timeIntervalSince1970: 999_600), count: 30)
        let oldestLoaded = firstPage.first!.start
        let olderPage = candlePage(endingAt: oldestLoaded.addingTimeInterval(-300), count: 2, price: 62_500)
        spotRepository.candlePages = [firstPage, olderPage]

        let vm = makeVM(repository: repository, windowEnd: windowEnd, spotRepository: spotRepository)
        vm.start()
        for _ in 0..<200 { await Task.yield() }
        vm.stop()

        XCTAssertEqual(vm.candles.count, 32)
        XCTAssertEqual(vm.candles.prefix(2).map(\.close), [62_500, 62_500], "older page must be prepended")
        XCTAssertEqual(spotRepository.candleBeforeCursors.count, 2)
        XCTAssertNil(spotRepository.candleBeforeCursors[0], "the first page has no cursor")
        XCTAssertEqual(spotRepository.candleBeforeCursors[1], oldestLoaded, "paging must cursor from the oldest loaded candle")
        XCTAssertFalse(vm.hasMoreCandles, "a short page means history is exhausted")
    }
}
