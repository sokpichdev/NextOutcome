//
//  RecurrenceCadenceTests.swift
//  NextOutcome
//
//  Created by Sok Pich on 18/08/2026.
//

import XCTest
@testable import MarketsDomain

final class RecurrenceCadenceTests: XCTestCase {
    func test_init_readsCadenceFromEverySeriesSlugSuffix() {
        XCTAssertEqual(RecurrenceCadence(seriesSlug: "btc-up-or-down-5m"), .fiveMinute)
        XCTAssertEqual(RecurrenceCadence(seriesSlug: "eth-up-or-down-15m"), .fifteenMinute)
        XCTAssertEqual(RecurrenceCadence(seriesSlug: "sol-up-or-down-hourly"), .hourly)
        XCTAssertEqual(RecurrenceCadence(seriesSlug: "btc-up-or-down-4h"), .fourHour)
        XCTAssertEqual(RecurrenceCadence(seriesSlug: "eth-up-or-down-daily"), .daily)
    }

    /// The load-bearing safety property: a series slug that isn't a recurring window —
    /// esports categories are the ones that actually reach this — must not read as a cadence.
    func test_init_isNilForNonCadenceSeries() {
        XCTAssertNil(RecurrenceCadence(seriesSlug: "league-of-legends"))
        XCTAssertNil(RecurrenceCadence(seriesSlug: nil))
        XCTAssertNil(RecurrenceCadence(seriesSlug: ""))
    }

    func test_windowSeconds_matchesEachCadence() {
        XCTAssertEqual(RecurrenceCadence.fiveMinute.windowSeconds, 300)
        XCTAssertEqual(RecurrenceCadence.fifteenMinute.windowSeconds, 900)
        XCTAssertEqual(RecurrenceCadence.hourly.windowSeconds, 3_600)
        XCTAssertEqual(RecurrenceCadence.fourHour.windowSeconds, 14_400)
        XCTAssertEqual(RecurrenceCadence.daily.windowSeconds, 86_400)
    }

    func test_shortLabel_matchesEachCadence() {
        XCTAssertEqual(RecurrenceCadence.fiveMinute.shortLabel, "5m")
        XCTAssertEqual(RecurrenceCadence.fifteenMinute.shortLabel, "15m")
        XCTAssertEqual(RecurrenceCadence.hourly.shortLabel, "1h")
        XCTAssertEqual(RecurrenceCadence.fourHour.shortLabel, "4h")
        XCTAssertEqual(RecurrenceCadence.daily.shortLabel, "Daily")
    }
}
