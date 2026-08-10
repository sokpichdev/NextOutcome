//
//  MarketBinaryOutcomesTests.swift
//  NextOutcome
//

import XCTest
@testable import MarketsDomain

final class MarketBinaryOutcomesTests: XCTestCase {

    /// Builds a market with the given outcome titles, priced in the order listed.
    private func market(_ titles: [String], prices: [Double]) -> Market {
        Market(
            id: "m", question: "q", slug: "q",
            outcomes: zip(titles, prices).map { Outcome(id: $0.0, title: $0.0, price: Decimal($0.1)) },
            volume: 0, liquidity: 0, endDate: nil, isResolved: false, imageURL: nil
        )
    }

    func test_yesNoMarket_answersWithTheNamedSides() {
        let sides = market(["Yes", "No"], prices: [0.31, 0.69]).binaryOutcomes
        XCTAssertEqual(sides?.first.title, "Yes")
        XCTAssertEqual(sides?.second.title, "No")
    }

    func test_yesNoMarket_isOrderIndependent() {
        // Gamma is not guaranteed to list Yes first, and the Yes side must stay the Yes side.
        let sides = market(["No", "Yes"], prices: [0.69, 0.31]).binaryOutcomes
        XCTAssertEqual(sides?.first.title, "Yes")
        XCTAssertEqual(sides?.first.price, Decimal(0.31))
        XCTAssertEqual(sides?.second.title, "No")
    }

    func test_teamNamedMarket_fallsBackToArrayOrder() {
        // The esports case that rendered no prices at all before this existed.
        let sides = market(["Eternal Fire Academy", "Vitality Academy"], prices: [0.405, 0.595]).binaryOutcomes
        XCTAssertEqual(sides?.first.title, "Eternal Fire Academy")
        XCTAssertEqual(sides?.first.price, Decimal(0.405))
        XCTAssertEqual(sides?.second.title, "Vitality Academy")
        XCTAssertEqual(sides?.second.price, Decimal(0.595))
    }

    func test_overUnderMarket_fallsBackToArrayOrder() {
        let sides = market(["Over", "Under"], prices: [0.995, 0.005]).binaryOutcomes
        XCTAssertEqual(sides?.first.title, "Over")
        XCTAssertEqual(sides?.second.title, "Under")
    }

    func test_nonBinaryMarkets_haveNoPair() {
        XCTAssertNil(market(["Only"], prices: [1.0]).binaryOutcomes)
        XCTAssertNil(market(["A", "B", "C"], prices: [0.3, 0.3, 0.4]).binaryOutcomes)
        XCTAssertNil(market([], prices: []).binaryOutcomes)
    }

    func test_primaryOutcome_quotesTheYesSideOrTheFirstSide() {
        XCTAssertEqual(market(["No", "Yes"], prices: [0.69, 0.31]).primaryOutcome?.title, "Yes")
        XCTAssertEqual(market(["Eternal Fire Academy", "Vitality Academy"], prices: [0.405, 0.595])
            .primaryOutcome?.title, "Eternal Fire Academy")
        XCTAssertNil(market(["A", "B", "C"], prices: [0.3, 0.3, 0.4]).primaryOutcome)
    }

    func test_primaryOutcome_stillFindsYesOnAThreeWayMarketThatHasOne() {
        // Not binary, so there's no pair — but a Yes side is still the right thing to quote.
        XCTAssertEqual(market(["Yes", "No", "Void"], prices: [0.5, 0.4, 0.1]).primaryOutcome?.title, "Yes")
    }
}
