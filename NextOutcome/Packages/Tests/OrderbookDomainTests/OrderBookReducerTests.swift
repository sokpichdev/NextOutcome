import XCTest
@testable import OrderbookDomain

final class OrderBookReducerTests: XCTestCase {
    private let asset = "token-1"

    func test_snapshot_sortsBidsDescAndAsksAsc() {
        let book = OrderBook(assetID: asset)
        let event = OrderBookEvent.snapshot(
            bids: [level("0.40", "10"), level("0.45", "5")],
            asks: [level("0.55", "8"), level("0.50", "3")],
            tickSize: dec("0.01"),
            lastTrade: dec("0.48")
        )

        let result = OrderBookReducer.reduce(book, event)

        XCTAssertEqual(result.bids.map(\.price), [dec("0.45"), dec("0.40")])
        XCTAssertEqual(result.asks.map(\.price), [dec("0.50"), dec("0.55")])
        XCTAssertEqual(result.bestBid, dec("0.45"))
        XCTAssertEqual(result.bestAsk, dec("0.50"))
        XCTAssertEqual(result.spread, dec("0.05"))
        XCTAssertEqual(result.tickSize, dec("0.01"))
    }

    func test_priceChange_upsertsLevel() {
        let book = seeded()
        let event = OrderBookEvent.priceChanges([
            LevelChange(side: .bid, price: dec("0.45"), size: dec("20")) // overwrite existing
        ])

        let result = OrderBookReducer.reduce(book, event)

        XCTAssertEqual(result.bids.first?.price, dec("0.45"))
        XCTAssertEqual(result.bids.first?.size, dec("20"))
    }

    func test_priceChange_zeroSizeRemovesLevel() {
        let book = seeded()
        let event = OrderBookEvent.priceChanges([
            LevelChange(side: .ask, price: dec("0.50"), size: dec("0"))
        ])

        let result = OrderBookReducer.reduce(book, event)

        XCTAssertFalse(result.asks.contains { $0.price == dec("0.50") })
        XCTAssertEqual(result.bestAsk, dec("0.55"))
    }

    func test_lastTrade_updatesWithoutTouchingLevels() {
        let book = seeded()
        let result = OrderBookReducer.reduce(book, .lastTrade(dec("0.51")))
        XCTAssertEqual(result.lastTradePrice, dec("0.51"))
        XCTAssertEqual(result.bids, book.bids)
    }

    // MARK: Helpers

    private func seeded() -> OrderBook {
        OrderBookReducer.reduce(OrderBook(assetID: asset), .snapshot(
            bids: [level("0.45", "5"), level("0.40", "10")],
            asks: [level("0.50", "3"), level("0.55", "8")],
            tickSize: dec("0.01"), lastTrade: nil
        ))
    }

    private func level(_ p: String, _ s: String) -> PriceLevel { PriceLevel(price: dec(p), size: dec(s)) }
    private func dec(_ s: String) -> Decimal { Decimal(string: s)! }
}
