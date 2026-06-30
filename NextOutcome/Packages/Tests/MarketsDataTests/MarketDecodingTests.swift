import XCTest
@testable import Networking
@testable import MarketsData

final class MarketDecodingTests: XCTestCase {
    func test_decimalString_parsesStringPrice() throws {
        let json = #"{"price": "0.62"}"#.data(using: .utf8)!

        struct Wrapper: Decodable { let price: DecimalString }
        let result = try JSONDecoder.polymarket.decode(Wrapper.self, from: json)

        XCTAssertEqual(result.price.wrappedValue, Decimal(string: "0.62"))
    }

    func test_marketDTO_decodesFromGammaShape() throws {
        let json = """
        {
          "id": "abc",
          "question": "Will X win?",
          "market_slug": "will-x-win",
          "tokens": [
            {"token_id": "t1", "outcome": "Yes", "price": "0.62"},
            {"token_id": "t2", "outcome": "No",  "price": "0.38"}
          ],
          "volume": "4200.00",
          "liquidity": "1100.00",
          "end_date_iso": null,
          "closed": false,
          "image": null
        }
        """.data(using: .utf8)!

        let dto = try JSONDecoder.polymarket.decode(MarketDTO.self, from: json)

        XCTAssertEqual(dto.question, "Will X win?")
        XCTAssertEqual(dto.tokens.count, 2)
        XCTAssertEqual(dto.tokens[0].price.wrappedValue, Decimal(string: "0.62"))
    }
}
