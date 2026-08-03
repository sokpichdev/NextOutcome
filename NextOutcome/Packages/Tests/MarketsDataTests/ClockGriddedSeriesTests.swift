import XCTest
import MarketsDomain

/// The clock arithmetic that locates a live recurring window. Anchored on real slugs
/// verified against Gamma on 2026-08-03 — see `docs/polymarket-crypto-hub-gaps.md` §2.
final class ClockGriddedSeriesTests: XCTestCase {
    private let series = ClockGriddedSeries.bitcoinUpDown5m

    /// Real slug/title pairs pulled from live Gamma. `btc-updown-5m-1785764400` was titled
    /// "Bitcoin Up or Down - August 3, 9:40AM-9:45AM ET" (13:40Z), confirming the timestamp
    /// is the window *start*.
    func test_slugMatchesLiveGammaSlugs() {
        XCTAssertEqual(series.slug(at: Date(timeIntervalSince1970: 1_785_764_400)), "btc-updown-5m-1785764400")
        XCTAssertEqual(series.slug(at: Date(timeIntervalSince1970: 1_785_764_100)), "btc-updown-5m-1785764100")
    }

    /// Any instant inside a window resolves to that window, not the next one.
    func test_anyInstantInsideAWindowSnapsToItsStart() {
        let start = 1_785_764_400.0
        for offset in [0.0, 1.0, 150.0, 299.0, 299.999] {
            XCTAssertEqual(
                series.slug(at: Date(timeIntervalSince1970: start + offset)),
                "btc-updown-5m-1785764400",
                "offset \(offset) fell outside its window"
            )
        }
    }

    /// The boundary instant belongs to the *new* window.
    func test_boundaryInstantBelongsToTheNextWindow() {
        XCTAssertEqual(
            series.slug(at: Date(timeIntervalSince1970: 1_785_764_700)),
            "btc-updown-5m-1785764700"
        )
    }

    /// The next boundary is what the refresh sleeps to; it must be the window end, which is
    /// also `slug epoch + 300` (verified against Gamma's `endDate`).
    func test_nextBoundaryIsTheWindowEnd() {
        let mid = Date(timeIntervalSince1970: 1_785_764_400 + 120)
        XCTAssertEqual(series.nextBoundary(after: mid), Date(timeIntervalSince1970: 1_785_764_700))
    }

    /// Scheduling must not degenerate at the exact boundary — the next boundary is always
    /// strictly ahead, or the refresh loop would spin.
    func test_nextBoundaryIsAlwaysInTheFuture() {
        for ts in [1_785_764_400.0, 1_785_764_401.0, 1_785_764_699.0] {
            let date = Date(timeIntervalSince1970: ts)
            XCTAssertGreaterThan(series.nextBoundary(after: date), date, "no forward progress at \(ts)")
        }
    }

    /// Instants before 1970 must floor backwards rather than truncate toward zero, which
    /// would place them in the following window.
    func test_preEpochInstantsFloorBackwards() {
        let s = ClockGriddedSeries(slugPrefix: "x", windowSeconds: 300)
        XCTAssertEqual(s.slug(at: Date(timeIntervalSince1970: -1)), "x--300")
    }

    /// A non-positive window would divide by zero; the initialiser clamps it.
    func test_nonPositiveWindowIsClamped() {
        XCTAssertEqual(ClockGriddedSeries(slugPrefix: "x", windowSeconds: 0).windowSeconds, 1)
        XCTAssertEqual(ClockGriddedSeries(slugPrefix: "x", windowSeconds: -5).windowSeconds, 1)
    }

    /// The shipped descriptor must match the series Polymarket actually uses.
    func test_bitcoinDescriptorMatchesPolymarket() {
        XCTAssertEqual(series.slugPrefix, "btc-updown-5m")
        XCTAssertEqual(series.windowSeconds, 300)
    }
}
