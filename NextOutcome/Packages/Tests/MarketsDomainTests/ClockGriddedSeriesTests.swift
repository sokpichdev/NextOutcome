//
//  ClockGriddedSeriesTests.swift
//  NextOutcome
//

import XCTest
@testable import MarketsDomain

/// Recovering a series from one of its windows, so a screen showing a single window can
/// ask for whichever window of the *same* series is live now.
final class ClockGriddedSeriesTests: XCTestCase {

    func test_initFromWindowSlug_stripsTheEpochToRecoverThePrefix() {
        let series = ClockGriddedSeries(windowSlug: "btc-updown-5m-1787069400", windowSeconds: 300)

        XCTAssertEqual(series?.slugPrefix, "btc-updown-5m")
        XCTAssertEqual(series?.windowSeconds, 300)
    }

    /// The point of deriving rather than hardcoding: the live screen opens for every coin
    /// and cadence, and "next window" must stay inside the series the user is watching.
    func test_initFromWindowSlug_keepsTheSeriesOfANonBitcoinCadence() {
        let series = ClockGriddedSeries(windowSlug: "eth-updown-1d-1787000000", windowSeconds: 86_400)

        XCTAssertEqual(series?.slugPrefix, "eth-updown-1d")
        XCTAssertEqual(series?.windowSeconds, 86_400)
    }

    /// Round trip: the recovered series must address its own windows again.
    func test_recoveredSeries_resolvesTheSlugOfTheWindowItCameFrom() {
        let series = ClockGriddedSeries(windowSlug: "btc-updown-5m-1787069400", windowSeconds: 300)
        let inside = Date(timeIntervalSince1970: 1_787_069_500)

        XCTAssertEqual(series?.slug(at: inside), "btc-updown-5m-1787069400")
    }

    func test_initFromWindowSlug_rejectsASlugWithNoEpoch() {
        XCTAssertNil(ClockGriddedSeries(windowSlug: "btc-updown-5m", windowSeconds: 300))
    }

    func test_initFromWindowSlug_rejectsAnEmptySlug() {
        XCTAssertNil(ClockGriddedSeries(windowSlug: "", windowSeconds: 300))
    }

    /// A trailing number is not enough — dropping it has to leave a prefix behind.
    func test_initFromWindowSlug_rejectsABareEpoch() {
        XCTAssertNil(ClockGriddedSeries(windowSlug: "1787069400", windowSeconds: 300))
    }
}
