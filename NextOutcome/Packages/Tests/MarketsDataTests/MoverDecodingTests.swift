import XCTest
import MarketsDomain
@testable import Networking
@testable import MarketsData

final class MoverDecodingTests: XCTestCase {
    /// Real Gamma `/markets` mover shape: stringified `outcomePrices`, numeric change/volume,
    /// and an `events` array pointing back at the parent event.
    func test_moverDTO_decodesAndMaps_fromGammaShape() throws {
        let json = """
        {
          "id": "m1",
          "question": "Will GPT-5.6 be released on July 7, 2026?",
          "outcomePrices": "[\\"0.08\\", \\"0.92\\"]",
          "lastTradePrice": 0.07,
          "oneDayPriceChange": -0.625,
          "volume24hr": 38892.25,
          "image": "https://img/market.png",
          "events": [
            { "slug": "gpt-5pt6-released", "title": "GPT-5.6 released on…?", "image": "https://img/event.png" }
          ]
        }
        """.data(using: .utf8)!

        let dto = try JSONDecoder.polymarket.decode(MoverDTO.self, from: json)
        let mover = MarketMapper.mover(from: dto)

        // Current chance prefers the first outcome price over lastTradePrice.
        XCTAssertEqual(mover.probability, Decimal(string: "0.08"))
        XCTAssertEqual(mover.dayChange, Decimal(string: "-0.625"))
        XCTAssertFalse(mover.isUp)
        XCTAssertEqual(mover.magnitude, Decimal(string: "0.625"))
        XCTAssertEqual(mover.eventSlug, "gpt-5pt6-released")
        XCTAssertEqual(mover.eventTitle, "GPT-5.6 released on…?")
        // Parent event image wins over the market image.
        XCTAssertEqual(mover.imageURL?.absoluteString, "https://img/event.png")
    }

    /// Falls back to `lastTradePrice` when `outcomePrices` is missing, and leaves `eventSlug`
    /// empty when the market has no parent event (those rows are dropped by the repository).
    func test_moverDTO_fallsBackToLastTrade_andEmptySlug_whenEventMissing() throws {
        let json = """
        { "id": "m2", "question": "Q", "lastTradePrice": 0.42, "oneDayPriceChange": 0.3, "volume24hr": 100 }
        """.data(using: .utf8)!

        let dto = try JSONDecoder.polymarket.decode(MoverDTO.self, from: json)
        let mover = MarketMapper.mover(from: dto)

        XCTAssertEqual(mover.probability, Decimal(string: "0.42"))
        XCTAssertTrue(mover.isUp)
        XCTAssertEqual(mover.eventSlug, "")
        XCTAssertEqual(mover.eventTitle, "Q")   // falls back to the question
    }
}
