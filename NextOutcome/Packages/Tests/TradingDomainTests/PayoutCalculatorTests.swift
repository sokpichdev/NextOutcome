//
//  PayoutCalculatorTests.swift
//  NextOutcome
//

import XCTest
@testable import TradingDomain

final class PayoutCalculatorTests: XCTestCase {
    func testTenDollarsAtFiftyCents() {
        let r = PayoutCalculator.potential(amountUSD: 10, priceCents: 50)
        XCTAssertEqual(r.shares, 20); XCTAssertEqual(r.payoutUSD, 20)
    }
    func testZeroPriceNeverDivides() {
        let r = PayoutCalculator.potential(amountUSD: 10, priceCents: 0)
        XCTAssertEqual(r.shares, 0); XCTAssertEqual(r.payoutUSD, 0)
    }
    func testRoundsHalfEvenToTwoPlaces() {
        let r = PayoutCalculator.potential(amountUSD: 1, priceCents: 3)
        XCTAssertEqual(r.payoutUSD, Decimal(string: "33.33"))
    }
}
