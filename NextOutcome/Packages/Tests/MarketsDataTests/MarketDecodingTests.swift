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

    /// Real market object (id 2718913, "Will Spain win on 2026-07-02?") captured from a live
    /// Gamma-shaped `/events/slug/fifwc-esp-aut-2026-07-02` response embedded in
    /// `~/Desktop/scripts/api_map.json` — verifies the new sports fields decode tolerantly.
    func test_marketDTO_decodesSportsFieldsFromRealGammaMarket() throws {
        let json = """
        {
          "id": "2718913",
          "conditionId": "0xc5943cca27ce657f519619520b1664829b1209f9a5ef9266be7f2954be1b0260",
          "question": "Will Spain win on 2026-07-02?",
          "slug": "fifwc-esp-aut-2026-07-02-esp",
          "outcomes": ["Yes", "No"],
          "outcomePrices": ["0.76375", "0.23625"],
          "active": true,
          "closed": false,
          "archived": false,
          "groupItemTitle": "Spain",
          "groupItemThreshold": "0",
          "sportsMarketType": "moneyline",
          "negRiskSportsMarketType": "home",
          "image": "https://polymarket-upload.s3.us-east-2.amazonaws.com/soccer ball-bba4025f77.png",
          "icon": "https://polymarket-upload.s3.us-east-2.amazonaws.com/soccer ball-bba4025f77.png",
          "clobTokenIds": [
            "110474601866909537724044216141585040787927916157559633438159999666255694855775",
            "87195879292900083989013965233465465154610009955293265578539308193346452705988"
          ]
        }
        """.data(using: .utf8)!

        let dto = try JSONDecoder.polymarket.decode(MarketDTO.self, from: json)

        XCTAssertEqual(dto.sportsMarketType, "moneyline")
        XCTAssertEqual(dto.groupItemTitle, "Spain")
    }

    func test_marketDTO_sportsFields_toleratesMissingOrMistyped() throws {
        let missing = #"{"id": "x", "question": "Q", "slug": "q"}"#.data(using: .utf8)!
        let missingDTO = try JSONDecoder.polymarket.decode(MarketDTO.self, from: missing)
        XCTAssertNil(missingDTO.sportsMarketType)
        XCTAssertNil(missingDTO.groupItemTitle)

        // Wrong type (number instead of string) must degrade to nil, never fail the decode.
        let mistyped = #"{"id": "x", "question": "Q", "slug": "q", "sportsMarketType": 42, "groupItemTitle": false}"#
            .data(using: .utf8)!
        let mistypedDTO = try JSONDecoder.polymarket.decode(MarketDTO.self, from: mistyped)
        XCTAssertNil(mistypedDTO.sportsMarketType)
        XCTAssertNil(mistypedDTO.groupItemTitle)
    }
}
