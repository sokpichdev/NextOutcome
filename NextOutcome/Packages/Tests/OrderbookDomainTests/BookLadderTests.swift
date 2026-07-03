//
//  BookLadderTests.swift
//  NextOutcome
//

import XCTest
@testable import OrderbookDomain

/// `PriceChange` in the task brief maps to the domain's existing `LevelChange` type
/// (side: `.bid`/`.ask` instead of `.buy`/`.sell`) — see task-6-report.md for the mapping note.
final class BookLadderTests: XCTestCase {

    func testCumulativeAndSpread() {
        let ladder = BookLadder.from(.fixture(
            bids: [(0.61, 100), (0.60, 50)],
            asks: [(0.63, 80), (0.64, 20)]
        ))

        XCTAssertEqual(ladder.spreadCents, 2)
        XCTAssertEqual(ladder.asks.map(\.cumulative), [80, 100])
    }

    func testBidsDescendingCumulativeFromSpreadOutward() {
        let ladder = BookLadder.from(.fixture(
            bids: [(0.61, 100), (0.60, 50)],
            asks: [(0.63, 80), (0.64, 20)]
        ))

        XCTAssertEqual(ladder.bids.map(\.price), [0.61, 0.60])
        XCTAssertEqual(ladder.bids.map(\.cumulative), [100, 150])
    }

    func testZeroSizeDeltaRemovesLevel() {
        let ladder = BookLadder.from(.fixture(bids: [(0.61, 100)], asks: [(0.63, 80)]))
            .applying(LevelChange(side: .bid, price: 0.61, size: 0))

        XCTAssertTrue(ladder.bids.isEmpty)
    }

    func testDeltaUpsertsAndRecomputesCumulative() {
        let ladder = BookLadder.from(.fixture(bids: [(0.61, 100)], asks: [(0.63, 80)]))
            .applying(LevelChange(side: .bid, price: 0.62, size: 30))

        XCTAssertEqual(ladder.bids.map(\.price), [0.62, 0.61])
        XCTAssertEqual(ladder.bids.map(\.cumulative), [30, 130])
    }

    func testDeltaReplacesExistingLevelSize() {
        let ladder = BookLadder.from(.fixture(bids: [(0.61, 100)], asks: [(0.63, 80)]))
            .applying(LevelChange(side: .bid, price: 0.61, size: 40))

        XCTAssertEqual(ladder.bids.map(\.size), [40])
        XCTAssertEqual(ladder.bids.map(\.cumulative), [40])
    }

    func testEmptyBookHasZeroSpread() {
        let ladder = BookLadder.from(.fixture(bids: [], asks: []))
        XCTAssertEqual(ladder.spreadCents, 0)
        XCTAssertTrue(ladder.bids.isEmpty)
        XCTAssertTrue(ladder.asks.isEmpty)
    }
}

private extension OrderBook {
    /// Test fixture: builds a book from `(price, size)` tuples, already correctly
    /// ordered (bids high→low, asks low→high) as `OrderBook` guarantees elsewhere.
    static func fixture(bids: [(Double, Double)], asks: [(Double, Double)]) -> OrderBook {
        OrderBook(
            assetID: "token-1",
            bids: bids.map { PriceLevel(price: Decimal($0.0), size: Decimal($0.1)) }
                .sorted { $0.price > $1.price },
            asks: asks.map { PriceLevel(price: Decimal($0.0), size: Decimal($0.1)) }
                .sorted { $0.price < $1.price }
        )
    }
}

private extension LevelChange {
    init(side: BookSide, price: Double, size: Double) {
        self.init(side: side, price: Decimal(price), size: Decimal(size))
    }
}
