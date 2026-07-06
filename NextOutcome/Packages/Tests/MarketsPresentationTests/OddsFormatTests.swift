//
//  OddsFormatTests.swift
//  NextOutcome
//

import XCTest
@testable import MarketsPresentation

final class OddsFormatTests: XCTestCase {
    func test_price_wholeCent() {
        XCTAssertEqual(OddsFormat.price.format(0.62), "62¢")
    }

    func test_percentage_wholePercent() {
        XCTAssertEqual(OddsFormat.percentage.format(0.62), "62%")
    }

    func test_decimal_evenOdds() {
        XCTAssertEqual(OddsFormat.decimal.format(0.5), "2.00")
    }

    func test_decimal_twoThirds() {
        XCTAssertEqual(OddsFormat.decimal.format(2.0 / 3.0), "1.50")
    }

    func test_american_evenOdds_isPlusOneHundred() {
        XCTAssertEqual(OddsFormat.american.format(0.5), "+100")
    }

    func test_american_favorite_isNegative() {
        // p = 2/3 -> American = -100 * p/(1-p) = -200
        XCTAssertEqual(OddsFormat.american.format(2.0 / 3.0), "-200")
    }

    func test_american_underdog_isPositive() {
        // p = 1/3 -> American = 100 * (1-p)/p = +200
        XCTAssertEqual(OddsFormat.american.format(1.0 / 3.0), "+200")
    }

    func test_hongKong_evenOdds() {
        XCTAssertEqual(OddsFormat.hongKong.format(0.5), "1.00")
    }

    func test_fractional_evenOdds_isOneToOne() {
        XCTAssertEqual(OddsFormat.fractional.format(0.5), "1/1")
    }

    func test_fractional_twoThirds_isOneToTwo() {
        // p = 2/3 -> (1-p)/p = 1/2
        XCTAssertEqual(OddsFormat.fractional.format(2.0 / 3.0), "1/2")
    }

    func test_indonesian_favorite_isNegative() {
        // p = 2/3 (favorite) -> -p/(1-p) = -2.00
        XCTAssertEqual(OddsFormat.indonesian.format(2.0 / 3.0), "-2.00")
    }

    func test_indonesian_underdog_isPositive() {
        // p = 1/3 (underdog) -> (1-p)/p = +2.00
        XCTAssertEqual(OddsFormat.indonesian.format(1.0 / 3.0), "+2.00")
    }

    func test_malaysian_favorite_isNegative_magnitudeAtMostOne() {
        // p = 2/3 (favorite) -> -(1-p)/p = -0.50
        XCTAssertEqual(OddsFormat.malaysian.format(2.0 / 3.0), "-0.50")
    }

    func test_malaysian_underdog_isPositive_magnitudeAtMostOne() {
        // p = 1/3 (underdog) -> p/(1-p) = +0.50
        XCTAssertEqual(OddsFormat.malaysian.format(1.0 / 3.0), "+0.50")
    }

    func test_extremePrices_fallBackToPrice() {
        XCTAssertEqual(OddsFormat.american.format(0), OddsFormat.price.format(0))
        XCTAssertEqual(OddsFormat.decimal.format(1), OddsFormat.price.format(1))
    }

    func test_allCases_haveTitles() {
        for format in OddsFormat.allCases {
            XCTAssertFalse(format.title.isEmpty)
        }
    }
}
