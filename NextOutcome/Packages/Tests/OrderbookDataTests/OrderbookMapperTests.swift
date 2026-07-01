import XCTest
import OrderbookDomain
@testable import OrderbookData

final class OrderbookMapperTests: XCTestCase {
    func test_bookMessage_mapsToSnapshot() throws {
        let json = """
        { "event_type": "book", "asset_id": "t1",
          "bids": [{"price": "0.40", "size": "10"}],
          "asks": [{"price": "0.55", "size": "8"}],
          "tick_size": "0.01" }
        """.data(using: .utf8)!
        let message = try JSONDecoder.polymarket.decode(MarketMessageDTO.self, from: json)

        let events = OrderbookMapper.events(from: message)

        guard case let .snapshot(bids, asks, tick, _) = events.first else {
            return XCTFail("expected snapshot, got \(events)")
        }
        XCTAssertEqual(bids.first?.price, Decimal(string: "0.40"))
        XCTAssertEqual(asks.first?.price, Decimal(string: "0.55"))
        XCTAssertEqual(tick, Decimal(string: "0.01"))
    }

    func test_priceChange_mapsSideAndRemoval() throws {
        let json = """
        { "event_type": "price_change", "asset_id": "t1",
          "changes": [
            {"price": "0.45", "size": "20", "side": "BUY"},
            {"price": "0.50", "size": "0",  "side": "SELL"}
          ] }
        """.data(using: .utf8)!
        let message = try JSONDecoder.polymarket.decode(MarketMessageDTO.self, from: json)

        guard case let .priceChanges(changes) = OrderbookMapper.events(from: message).first else {
            return XCTFail("expected priceChanges")
        }
        XCTAssertEqual(changes[0].side, .bid)
        XCTAssertEqual(changes[0].size, Decimal(string: "20"))
        XCTAssertEqual(changes[1].side, .ask)
        XCTAssertEqual(changes[1].size, 0)
    }
}
