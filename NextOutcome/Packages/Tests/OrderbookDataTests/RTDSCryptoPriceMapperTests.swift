import XCTest
import OrderbookDomain
@testable import OrderbookData
import Foundation

final class RTDSCryptoPriceMapperTests: XCTestCase {
    /// A `crypto_prices_chainlink` `update` frame whose payload symbol matches the target
    /// must decode to a `CryptoSpotPricePoint`: millisecond timestamp → `Date`, `value` →
    /// dollar `Decimal`. (Live wire format captured from the RTDS server: the chainlink
    /// topic keys on lowercase `"btc/usd"`-style pairs.)
    func test_chainlinkUpdate_decodesToPoint() {
        let json = """
        { "topic": "crypto_prices_chainlink", "type": "update", "timestamp": 1710000123999,
          "payload": { "symbol": "btc/usd", "timestamp": 1710000123456, "value": 62464.5 },
          "connection_id": "abc" }
        """.data(using: .utf8)!

        let point = RTDSCryptoPriceMapper.point(from: json, exchangeSymbol: "btc/usd")

        XCTAssertEqual(point?.price, Decimal(62464.5))
        XCTAssertEqual(point?.date, Date(timeIntervalSince1970: 1_710_000_123.456))
    }

    /// A frame for a different asset must be ignored (defense in depth even though the
    /// subscription is server-side filtered by symbol).
    func test_mismatchedSymbol_returnsNil() {
        let json = """
        { "topic": "crypto_prices_chainlink", "type": "update", "timestamp": 1,
          "payload": { "symbol": "eth/usd", "timestamp": 1, "value": 3400 }, "connection_id": "x" }
        """.data(using: .utf8)!

        XCTAssertNil(RTDSCryptoPriceMapper.point(from: json, exchangeSymbol: "btc/usd"))
    }

    /// Non-price frames (connection acks, empty keep-alive frames) must map to no point
    /// rather than crashing.
    func test_nonPriceFrame_returnsNil() {
        let ack = """
        { "topic": "connection", "type": "connected", "timestamp": 1, "connection_id": "x" }
        """.data(using: .utf8)!

        XCTAssertNil(RTDSCryptoPriceMapper.point(from: ack, exchangeSymbol: "btc/usd"))
        XCTAssertNil(RTDSCryptoPriceMapper.point(from: Data("not json".utf8), exchangeSymbol: "btc/usd"))
    }

    /// The app carries plain asset symbols ("BTC", "ETH", …); the chainlink topic keys on
    /// lowercase `"<coin>/usd"` pairs. The mapper must translate, and be idempotent if the
    /// value is already a pair.
    func test_exchangeSymbol_mapsAssetToChainlinkPair() {
        XCTAssertEqual(RTDSCryptoPriceMapper.exchangeSymbol(for: "BTC"), "btc/usd")
        XCTAssertEqual(RTDSCryptoPriceMapper.exchangeSymbol(for: "eth"), "eth/usd")
        XCTAssertEqual(RTDSCryptoPriceMapper.exchangeSymbol(for: "SOL"), "sol/usd")
        XCTAssertEqual(RTDSCryptoPriceMapper.exchangeSymbol(for: "btc/usd"), "btc/usd")
    }

    /// The subscription message must carry `action: "subscribe"` (without it the RTDS server
    /// silently streams nothing — verified against the live server) and target the chainlink
    /// topic. It intentionally does **not** server-filter by symbol: the chainlink topic's
    /// server-side symbol filter was found unreliable against the live feed, so we subscribe
    /// to all symbols and filter client-side in `point(from:exchangeSymbol:)`.
    func test_subscribeMessage_carriesActionAndChainlinkTopic() throws {
        let data = RTDSCryptoPriceMapper.subscribeMessage()
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(root["action"] as? String, "subscribe")
        let subs = try XCTUnwrap(root["subscriptions"] as? [[String: Any]])
        XCTAssertEqual(subs.first?["topic"] as? String, "crypto_prices_chainlink")
    }
}
