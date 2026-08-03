import XCTest
import OrderbookDomain
@testable import OrderbookPresentation

/// A candle here is the 5-minute betting window itself, not an arbitrary chart bucket. During
/// an open window that means exactly one candle, forming in place.
/// See `docs/polymarket-live-chart-study.md`.
final class CandleBucketingTests: XCTestCase {
    private func point(_ offset: TimeInterval, _ price: Decimal) -> CryptoSpotPricePoint {
        CryptoSpotPricePoint(date: Date(timeIntervalSince1970: offset), price: price)
    }

    /// The headline property: a whole window is one candle, whatever the sample rate.
    ///
    /// The price feed is window-scoped — asking it for two hours still returns only the
    /// current window — so anything finer chops one real window into invented sub-candles.
    func test_oneWindowIsOneCandle() {
        // 0…240s — five samples inside one 300s window (300 would open the next one).
        let oncePerMinute = (0..<5).map { point(Double($0) * 60, 63_800 + Decimal($0)) }
        XCTAssertEqual(BTCLiveViewModel.bucket(oncePerMinute, interval: 300).count, 1)

        let onceASecond = (0..<300).map { point(Double($0), 63_800 + Decimal($0 % 5)) }
        XCTAssertEqual(BTCLiveViewModel.bucket(onceASecond, interval: 300).count, 1)
    }

    /// The candle's open is the window's opening price and its close the latest — the two
    /// values the header shows as "price to beat" and "current price".
    func test_candleOpensAtTheWindowOpenAndClosesAtTheLatestPrice() {
        let points = [point(0, 63_800), point(60, 63_900), point(120, 63_700), point(180, 63_850)]
        let candle = BTCLiveViewModel.bucket(points, interval: 300)[0]
        XCTAssertEqual(candle.open, 63_800)
        XCTAssertEqual(candle.close, 63_850)
        XCTAssertEqual(candle.high, 63_900)
        XCTAssertEqual(candle.low, 63_700)
    }

    /// New ticks mutate the forming candle rather than adding bars — the whole point of the
    /// change. Its close follows the price and its high/low stretch to the extremes.
    func test_ticksFormTheCandleInPlaceInsteadOfAddingBars() {
        var points = [point(0, 63_800)]
        for second in stride(from: 1.0, through: 240, by: 1) {
            points.append(point(second, 63_800 + Decimal(Int(second) % 60)))
        }
        let candles = BTCLiveViewModel.bucket(points, interval: 300)
        XCTAssertEqual(candles.count, 1, "240 ticks inside one window must stay one candle")
        XCTAssertEqual(candles[0].open, 63_800)
        XCTAssertEqual(candles[0].high, 63_859)
    }

    /// Colour is a function of close vs open, so a candle flips as the price crosses back
    /// over the window's opening price. (The view maps this to green/red.)
    func test_candleDirectionFlipsAsPriceCrossesTheOpen() {
        let up = BTCLiveViewModel.bucket([point(0, 63_800), point(60, 63_900)], interval: 300)[0]
        XCTAssertGreaterThan(up.close, up.open, "above the open reads as up")

        let down = BTCLiveViewModel.bucket([point(0, 63_800), point(60, 63_700)], interval: 300)[0]
        XCTAssertLessThan(down.close, down.open, "below the open reads as down")
    }

    /// Consecutive windows are separate candles, so a longer feed would render one bar per
    /// window — two hours as 24 five-minute candles, matching the web.
    func test_consecutiveWindowsBecomeSeparateCandles() {
        let points = [point(0, 63_800), point(299, 63_850), point(300, 63_900), point(599, 63_950)]
        let candles = BTCLiveViewModel.bucket(points, interval: 300)
        XCTAssertEqual(candles.count, 2)
        XCTAssertEqual(candles[0].close, 63_850)
        XCTAssertEqual(candles[1].open, 63_900)
    }

    /// Buckets anchor to absolute time, so a candle keeps its boundaries as the window fills.
    /// Anchoring to the first sample would shift the bar on every new point.
    func test_bucketsAnchorToAbsoluteTimeNotFirstSample() {
        let candles = BTCLiveViewModel.bucket([point(360, 100), point(660, 110)], interval: 300)
        XCTAssertEqual(candles[0].start, Date(timeIntervalSince1970: 300))
        XCTAssertEqual(candles[1].start, Date(timeIntervalSince1970: 600))
    }

    /// A window with one sample so far is a valid flat candle, not a dropped one — this is
    /// what a window looks like the instant it opens.
    func test_freshWindowWithOneSampleIsAFlatCandle() {
        let candles = BTCLiveViewModel.bucket([point(0, 63_800)], interval: 300)
        XCTAssertEqual(candles.count, 1)
        XCTAssertEqual(candles[0].open, candles[0].close)
        XCTAssertEqual(candles[0].high, candles[0].low)
    }

    func test_emptySeriesProducesNoCandles() {
        XCTAssertTrue(BTCLiveViewModel.bucket([], interval: 300).isEmpty)
    }

    /// A non-positive interval would divide by zero.
    func test_nonPositiveIntervalIsRejected() {
        XCTAssertTrue(BTCLiveViewModel.bucket([point(0, 100)], interval: 0).isEmpty)
    }
}
