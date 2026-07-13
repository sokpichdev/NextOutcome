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
private final class FakeCryptoSpotPriceRepository: CryptoSpotPriceRepository, @unchecked Sendable {
    var points: [CryptoSpotPricePoint] = []
    var window: CryptoPriceWindow = CryptoPriceWindow(
        openPrice: 0, closePrice: nil, timestamp: Date(), completed: false
    )
    /// The `symbol` argument each call was actually invoked with, so tests can assert
    /// the view model doesn't hardcode "BTC" for a non-Bitcoin market.
    private(set) var requestedSymbols: [String] = []

    func spotPriceHistory(symbol: String, eventStart: Date, eventEnd: Date) async throws -> [CryptoSpotPricePoint] {
        requestedSymbols.append(symbol)
        return points
    }

    func priceWindow(symbol: String, eventStart: Date, eventEnd: Date) async throws -> CryptoPriceWindow {
        requestedSymbols.append(symbol)
        return window
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
            onQuickBet: { _ in }
        )
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

    /// `.candles` builds dollar OHLC candles by aggregating the (now high-frequency) RTDS
    /// spot ticks into fixed time buckets — not the 0…1 probability series, and not one
    /// candle per raw tick. Dense ticks within a bucket collapse to one open/high/low/close.
    @MainActor
    func test_candles_aggregateDenseSpotTicksIntoOHLCBuckets() async {
        let windowEnd = Date(timeIntervalSince1970: 1_000_000)
        let repository = FakeOrderbookRepository()
        repository.points = [PriceHistoryPoint(date: windowEnd.addingTimeInterval(-60), price: 0.5)]

        let spotRepository = FakeCryptoSpotPriceRepository()
        let b0 = Date(timeIntervalSince1970: 0) // aligns to a 15s bucket boundary
        spotRepository.points = [
            CryptoSpotPricePoint(date: b0.addingTimeInterval(1), price: 63_900),  // open, bucket 0
            CryptoSpotPricePoint(date: b0.addingTimeInterval(5), price: 63_960),  // high, bucket 0
            CryptoSpotPricePoint(date: b0.addingTimeInterval(9), price: 63_880),  // low, bucket 0
            CryptoSpotPricePoint(date: b0.addingTimeInterval(14), price: 63_920), // close, bucket 0
            CryptoSpotPricePoint(date: b0.addingTimeInterval(16), price: 63_930), // open, bucket 1
            CryptoSpotPricePoint(date: b0.addingTimeInterval(29), price: 64_010), // close/high, bucket 1
        ]

        let vm = makeVM(repository: repository, windowEnd: windowEnd, spotRepository: spotRepository)
        vm.start()
        for _ in 0..<20 { await Task.yield() }
        vm.stop()

        let candles = vm.candles
        XCTAssertEqual(candles.count, 2, "6 ticks across two 15s buckets → 2 candles, not 5 pair-candles")
        XCTAssertEqual(candles[0].open, 63_900)
        XCTAssertEqual(candles[0].high, 63_960)
        XCTAssertEqual(candles[0].low, 63_880)
        XCTAssertEqual(candles[0].close, 63_920)
        XCTAssertNotEqual(candles[0].high, candles[0].low, "a bucket with real movement must not be a flat dot")
        XCTAssertEqual(candles[1].open, 63_930)
        XCTAssertEqual(candles[1].close, 64_010)
    }

    /// The dollar charts must scale their y-axis to the data (min…max across the spot series,
    /// plus the price-to-beat), not from 0 — otherwise BTC's ~$63k candles collapse to a flat
    /// line on a 0…100k axis.
    @MainActor
    func test_spotPriceBounds_spanSeriesAndPriceToBeat() async {
        let windowEnd = Date().addingTimeInterval(300)
        let repository = FakeOrderbookRepository()
        repository.points = [PriceHistoryPoint(date: Date(), price: 0.5)]

        let spotRepository = FakeCryptoSpotPriceRepository()
        spotRepository.points = [
            CryptoSpotPricePoint(date: Date().addingTimeInterval(-30), price: 62_800),
            CryptoSpotPricePoint(date: Date(), price: 62_950),
        ]
        spotRepository.window = CryptoPriceWindow(openPrice: 63_100, closePrice: nil, timestamp: Date(), completed: false)

        let vm = makeVM(repository: repository, windowEnd: windowEnd, spotRepository: spotRepository)
        vm.start()
        for _ in 0..<20 { await Task.yield() }
        vm.stop()

        let bounds = vm.spotPriceBounds
        XCTAssertEqual(bounds?.min, 62_800)
        XCTAssertEqual(bounds?.max, 63_100, "max must include the price-to-beat (63,100), above the series max")
    }

    /// The chart y-domain must pad *relative* to the price, not by a fixed dollar amount. A
    /// ~$76 coin (e.g. SOL) moving in a ~$0.3 band must keep a tight domain — a fixed ~$1 pad
    /// would swamp the range and squash the candles into a flat line (the "not candling" bug
    /// on low-priced coins).
    @MainActor
    func test_spotChartDomain_padsRelatively_keepsLowPricedCoinTight() async {
        let windowEnd = Date().addingTimeInterval(300)
        let repository = FakeOrderbookRepository()
        repository.points = [PriceHistoryPoint(date: Date(), price: 0.5)]

        let spotRepository = FakeCryptoSpotPriceRepository()
        spotRepository.points = [
            CryptoSpotPricePoint(date: Date().addingTimeInterval(-30), price: Decimal(string: "75.60")!),
            CryptoSpotPricePoint(date: Date(), price: Decimal(string: "75.90")!),
        ]
        // openPrice nil → no price-to-beat, so the domain reflects only the series.
        spotRepository.window = CryptoPriceWindow(openPrice: nil, closePrice: nil, timestamp: Date(), completed: false)

        let vm = makeVM(repository: repository, windowEnd: windowEnd, spotRepository: spotRepository)
        vm.start()
        for _ in 0..<20 { await Task.yield() }
        vm.stop()

        guard let domain = vm.spotChartDomain else { return XCTFail("expected a chart domain") }
        XCTAssertLessThan(
            domain.upperBound - domain.lowerBound, 1.0,
            "a ~$76 coin in a $0.3 band must keep a tight domain, not a fixed ~$1 pad"
        )
        XCTAssertGreaterThan(domain.lowerBound, 75.0)
        XCTAssertLessThan(domain.upperBound, 76.5)
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
}
