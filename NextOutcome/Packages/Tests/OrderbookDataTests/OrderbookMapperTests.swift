//
//  OrderbookMapperTests.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

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

    /// `/api/chainlink-candles` samples arrive as epoch-second `time` plus Double OHLC;
    /// the mapper must convert to domain candles and sort ascending regardless of the
    /// order the server sent them in.
    func test_chainlinkCandles_mapUnitsAndSortAscending() throws {
        let json = """
        { "candles": [
            {"time": 1785765000, "open": 63000.5, "high": 63100.1, "low": 62950.2, "close": 63050.8},
            {"time": 1785764700, "open": 62900.0, "high": 62950.0, "low": 62800.0, "close": 62947.7}
        ] }
        """.data(using: .utf8)!
        let dto = try JSONDecoder().decode(ChainlinkCandlesResponseDTO.self, from: json)

        let candles = OrderbookMapper.candles(from: dto)

        XCTAssertEqual(candles.count, 2)
        XCTAssertEqual(candles[0].start, Date(timeIntervalSince1970: 1_785_764_700))
        XCTAssertEqual(candles[1].start, Date(timeIntervalSince1970: 1_785_765_000))
        XCTAssertEqual(candles[0].open, Decimal(62_900.0))
        XCTAssertEqual(candles[0].close, Decimal(62_947.7))
        XCTAssertEqual(candles[1].high, Decimal(63_100.1))
        XCTAssertEqual(candles[1].low, Decimal(62_950.2))
    }
}
