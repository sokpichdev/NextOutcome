//
//  SimulatedTradeSubmitterTests.swift
//  NextOutcome
//

import XCTest
@testable import TradingDomain

final class SimulatedTradeSubmitterTests: XCTestCase {
    func test_simulatedSubmitter_returnsSimulatedReceipt() async throws {
        let submitter = SimulatedTradeSubmitter()
        let amountUSD: Decimal = 10
        let priceCents: Decimal = 50

        let receipt = try await submitter.submit(
            marketID: "m1",
            side: .yes,
            amountUSD: amountUSD,
            priceCents: priceCents
        )

        let expected = PayoutCalculator.potential(amountUSD: amountUSD, priceCents: priceCents)
        XCTAssertTrue(receipt.simulated)
        XCTAssertEqual(receipt.shares, expected.shares)
    }
}
