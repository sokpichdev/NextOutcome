import XCTest
import MarketsDomain
@testable import Networking
@testable import MarketsData

final class HolderDecodingTests: XCTestCase {
    func test_holders_groupsFlattenSortAndLabelOutcome() throws {
        let json = """
        [
          { "token": "yes", "holders": [
            { "proxyWallet": "0xAAAA000000000000000000000000000000000001", "name": "Whale", "outcomeIndex": 0, "amount": 5000 }
          ]},
          { "token": "no", "holders": [
            { "proxyWallet": "0xBBBB000000000000000000000000000000000002", "outcomeIndex": 1, "shares": "9000" }
          ]}
        ]
        """.data(using: .utf8)!
        let groups = try JSONDecoder.polymarket.decode([HolderGroupDTO].self, from: json)
        let holders = MarketMapper.holders(from: groups)

        XCTAssertEqual(holders.count, 2)
        XCTAssertEqual(holders.first?.shares, 9000)          // sorted by shares desc
        XCTAssertEqual(holders.first?.outcome, "No")
        XCTAssertEqual(holders.last?.name, "Whale")          // name preferred
        XCTAssertEqual(holders.last?.outcome, "Yes")
    }
}

final class MarketDecodingTests: XCTestCase {
    func test_decimalString_parsesStringPrice() throws {
        let json = #"{"price": "0.62"}"#.data(using: .utf8)!

        struct Wrapper: Decodable { let price: DecimalString }
        let result = try JSONDecoder.polymarket.decode(Wrapper.self, from: json)

        XCTAssertEqual(result.price.wrappedValue, Decimal(string: "0.62"))
    }

    func test_marketDTO_decodesFromGammaShape() throws {
        // Real Gamma `/events`-embedded market: stringified parallel arrays, `slug`, string volume.
        let json = """
        {
          "id": "abc",
          "question": "Will X win?",
          "slug": "will-x-win",
          "outcomes": "[\\"Yes\\", \\"No\\"]",
          "outcomePrices": "[\\"0.62\\", \\"0.38\\"]",
          "clobTokenIds": "[\\"t1\\", \\"t2\\"]",
          "volume": "4200.00",
          "endDateIso": "2024-05-13",
          "closed": false
        }
        """.data(using: .utf8)!

        let dto = try JSONDecoder.polymarket.decode(MarketDTO.self, from: json)

        XCTAssertEqual(dto.question, "Will X win?")
        XCTAssertEqual(dto.slug, "will-x-win")
        XCTAssertEqual(dto.outcomes, ["Yes", "No"])
        XCTAssertEqual(dto.outcomePrices, [Decimal(string: "0.62"), Decimal(string: "0.38")])
        XCTAssertEqual(dto.clobTokenIds, ["t1", "t2"])
        XCTAssertEqual(dto.volume, Decimal(string: "4200.00"))
        XCTAssertEqual(dto.liquidity, 0)   // absent → tolerant default
    }

    func test_marketDTO_toleratesMissingArrays() throws {
        let json = #"{"id": "x", "question": "Q", "slug": "q", "volume": 12.5}"#.data(using: .utf8)!
        let dto = try JSONDecoder.polymarket.decode(MarketDTO.self, from: json)
        XCTAssertEqual(dto.outcomes, [])
        XCTAssertEqual(dto.outcomePrices, [])
        XCTAssertFalse(dto.closed)
    }
}
