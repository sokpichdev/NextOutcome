import XCTest
import OrderbookDomain
@testable import OrderbookPresentation

/// Candles are bucketed by time, not drawn one per sample — the web widens its bars as the
/// range grows rather than adding one per tick. See `docs/polymarket-live-chart-study.md`.
final class CandleBucketingTests: XCTestCase {
    private func point(_ offset: TimeInterval, _ price: Decimal) -> CryptoSpotPricePoint {
        CryptoSpotPricePoint(date: Date(timeIntervalSince1970: offset), price: price)
    }

    // MARK: interval selection

    /// A five-minute window stays on a fine bar; a multi-hour range widens.
    func test_intervalWidensWithSpan() {
        XCTAssertEqual(BTCLiveViewModel.candleInterval(forSpan: 300), 15)      // 5m  -> 20 bars
        XCTAssertEqual(BTCLiveViewModel.candleInterval(forSpan: 3_600), 300)   // 1h  -> 12 bars
        XCTAssertEqual(BTCLiveViewModel.candleInterval(forSpan: 7_200), 300)   // 2h  -> 24 bars
        XCTAssertEqual(BTCLiveViewModel.candleInterval(forSpan: 86_400), 3_600) // 24h -> 24 bars
    }

    /// Whatever the span, the chart stays in a readable band rather than growing forever.
    func test_intervalKeepsCandleCountBounded() {
        for span in [60.0, 300, 900, 3_600, 21_600, 86_400, 604_800, 2_592_000] {
            let interval = BTCLiveViewModel.candleInterval(forSpan: span)
            XCTAssertLessThanOrEqual(
                span / interval, Double(BTCLiveViewModel.targetCandleCount),
                "span \(span) produced \(span / interval) candles"
            )
        }
    }

    /// Degenerate spans must not divide by zero or return nothing.
    func test_zeroSpanFallsBackToFinestInterval() {
        XCTAssertEqual(BTCLiveViewModel.candleInterval(forSpan: 0), BTCLiveViewModel.candleIntervals[0])
    }

    // MARK: bucketing

    /// OHLC is taken across the whole bucket, not just its endpoints — the wick has to carry
    /// the extremes, which the old adjacent-pair approach could never show.
    func test_bucketTakesOHLCAcrossTheWholeBucket() {
        let points = [
            point(0, 100),   // open
            point(10, 130),  // high
            point(20, 90),   // low
            point(30, 110),  // close
        ]
        let candles = BTCLiveViewModel.bucket(points, interval: 60)
        XCTAssertEqual(candles.count, 1)
        XCTAssertEqual(candles[0].open, 100)
        XCTAssertEqual(candles[0].high, 130)
        XCTAssertEqual(candles[0].low, 90)
        XCTAssertEqual(candles[0].close, 110)
    }

    /// Points falling in different windows become separate candles.
    func test_pointsSplitAcrossBuckets() {
        let candles = BTCLiveViewModel.bucket([point(0, 100), point(59, 105), point(60, 200)], interval: 60)
        XCTAssertEqual(candles.count, 2)
        XCTAssertEqual(candles[0].close, 105)
        XCTAssertEqual(candles[1].open, 200)
    }

    /// Buckets are anchored to absolute time, so a candle keeps its boundaries as the series
    /// grows. Anchoring to the first sample instead would shift every bar on each new point.
    func test_bucketsAnchorToAbsoluteTimeNotFirstSample() {
        let candles = BTCLiveViewModel.bucket([point(90, 100), point(150, 110)], interval: 60)
        XCTAssertEqual(candles[0].start, Date(timeIntervalSince1970: 60))
        XCTAssertEqual(candles[1].start, Date(timeIntervalSince1970: 120))
    }

    /// The point of the change: ticks arriving inside the current bucket update it in place
    /// rather than adding bars, so the chart stops redrawing every second.
    func test_newTicksInsideABucketDoNotAddCandles() {
        var points = [point(0, 100)]
        let before = BTCLiveViewModel.bucket(points, interval: 60).count
        for second in stride(from: 1.0, through: 50, by: 1) {
            points.append(point(second, 100 + Decimal(second)))
        }
        let after = BTCLiveViewModel.bucket(points, interval: 60)
        XCTAssertEqual(after.count, before, "50 ticks in one bucket must stay one candle")
        XCTAssertEqual(after[0].high, 150, "but the bucket's high must track them")
        XCTAssertEqual(after[0].close, 150)
    }

    /// A bucket holding a single sample is a valid flat candle, not a dropped one.
    func test_singlePointBucketIsAFlatCandle() {
        let candles = BTCLiveViewModel.bucket([point(0, 100)], interval: 60)
        XCTAssertEqual(candles.count, 1)
        XCTAssertEqual(candles[0].open, candles[0].close)
        XCTAssertEqual(candles[0].high, candles[0].low)
    }

    func test_emptySeriesProducesNoCandles() {
        XCTAssertTrue(BTCLiveViewModel.bucket([], interval: 60).isEmpty)
    }

    /// A non-positive interval would divide by zero.
    func test_nonPositiveIntervalIsRejected() {
        XCTAssertTrue(BTCLiveViewModel.bucket([point(0, 100)], interval: 0).isEmpty)
    }
}

/// The density floor: bucketing must never be finer than the samples actually arrive, or a
/// sparse series turns into a row of flat dots in mostly-empty buckets.
final class CandleDensityFloorTests: XCTestCase {
    private func point(_ offset: TimeInterval, _ price: Decimal) -> CryptoSpotPricePoint {
        CryptoSpotPricePoint(date: Date(timeIntervalSince1970: offset), price: price)
    }

    /// The REST seed lands about once a minute. A span-derived 15s bucket would leave most
    /// buckets empty; the floor lifts it to the sample rate.
    func test_sparseSeriesFloorsToTheSampleRate() {
        let oncePerMinute = (0..<5).map { point(Double($0) * 60, 100 + Decimal($0)) }
        let interval = BTCLiveViewModel.bucketInterval(for: oncePerMinute)
        XCTAssertGreaterThanOrEqual(interval, 60, "must not bucket finer than samples arrive")
    }

    /// Every bucket must contain at least one sample — no empty bars.
    func test_sparseSeriesProducesNoEmptyBuckets() {
        let oncePerMinute = (0..<5).map { point(Double($0) * 60, 100 + Decimal($0)) }
        let candles = BTCLiveViewModel.bucket(oncePerMinute, interval: BTCLiveViewModel.bucketInterval(for: oncePerMinute))
        XCTAssertLessThanOrEqual(candles.count, oncePerMinute.count)
        XCTAssertFalse(candles.isEmpty)
    }

    /// Dense live tick data is driven by the span instead, so the bar count stays readable.
    func test_denseSeriesIsDrivenBySpan() {
        let perSecond = (0..<300).map { point(Double($0), 100 + Decimal($0 % 7)) }
        let interval = BTCLiveViewModel.bucketInterval(for: perSecond)
        let candles = BTCLiveViewModel.bucket(perSecond, interval: interval)
        XCTAssertLessThanOrEqual(candles.count, BTCLiveViewModel.targetCandleCount + 1)
        XCTAssertGreaterThan(candles.count, 1, "a 5-minute tick series should still show bars")
    }

    /// A one-sample series can't imply a rate; it must not crash or divide by zero.
    func test_singleSampleIsSafe() {
        XCTAssertEqual(BTCLiveViewModel.bucketInterval(for: [point(0, 100)]), BTCLiveViewModel.candleIntervals[0])
    }
}
