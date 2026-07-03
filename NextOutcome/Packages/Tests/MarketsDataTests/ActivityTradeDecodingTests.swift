import XCTest
import MarketsDomain
@testable import Networking
@testable import MarketsData

final class ActivityTradeDecodingTests: XCTestCase {
    /// Real trades captured from a live Data-API `/trades?market=<conditionId>` response,
    /// embedded in `~/Desktop/scripts/api_map.json` (page 17, call index 25). Verbatim,
    /// trimmed to two complete objects from the response array.
    private static let realTradesJSON = """
    [{"proxyWallet":"0x0f3433d8b7596000bf1046aa822308d93cf67684","side":"BUY","asset":"110474601866909537724044216141585040787927916157559633438159999666255694855775","conditionId":"0xc5943cca27ce657f519619520b1664829b1209f9a5ef9266be7f2954be1b0260","size":15,"price":0.765,"timestamp":1783008527,"title":"Will Spain win on 2026-07-02?","slug":"fifwc-esp-aut-2026-07-02-esp","icon":"https://polymarket-upload.s3.us-east-2.amazonaws.com/soccer ball-bba4025f77.png","eventSlug":"fifwc-esp-aut-2026-07-02","outcome":"Yes","outcomeIndex":0,"name":"","pseudonym":"","bio":"","profileImage":"","profileImageOptimized":"","transactionHash":"0x57e94d52987f4f169c0d2eab2f491a45b4a2747132d124d1173b672c9aeed505"},{"proxyWallet":"0x44461806c4fdbfafeae351cfb9b873f7f7f3f12e","side":"BUY","asset":"110474601866909537724044216141585040787927916157559633438159999666255694855775","conditionId":"0xc5943cca27ce657f519619520b1664829b1209f9a5ef9266be7f2954be1b0260","size":10,"price":0.765,"timestamp":1783008527,"title":"Will Spain win on 2026-07-02?","slug":"fifwc-esp-aut-2026-07-02-esp","icon":"https://polymarket-upload.s3.us-east-2.amazonaws.com/soccer ball-bba4025f77.png","eventSlug":"fifwc-esp-aut-2026-07-02","outcome":"Yes","outcomeIndex":0,"name":"NYC-NO.1-Jungle-FanYang","pseudonym":"Enchanting-Populist","bio":"","profileImage":"","profileImageOptimized":"","transactionHash":"0x2e34c255aaf68780608cb9b48671f3edd6b4f10377690d97a77763b8fd8d40be"}]
    """.data(using: .utf8)!

    func test_activityTradeDTO_decodesFromRealDataAPITradesShape() throws {
        let dtos = try JSONDecoder.polymarket.decode([ActivityTradeDTO].self, from: Self.realTradesJSON)
        XCTAssertEqual(dtos.count, 2)

        let trades = MarketMapper.trades(from: dtos)
        let first = try XCTUnwrap(trades.first)

        XCTAssertEqual(first.side, .buy)
        XCTAssertEqual(first.size, 15)
        XCTAssertEqual(first.price, Decimal(string: "0.765"))
        XCTAssertEqual(first.outcome, "Yes")
        XCTAssertEqual(first.timestamp, Date(timeIntervalSince1970: 1783008527))
        // empty "name" falls through to shortened wallet, matching HolderRow's precedent.
        XCTAssertEqual(first.actorName, "0x0f34…7684")

        let second = trades[1]
        XCTAssertEqual(second.actorName, "NYC-NO.1-Jungle-FanYang")
    }

    func test_activityTradeDTO_sellSideMaps() throws {
        let json = """
        [{"proxyWallet":"0xabc","side":"SELL","size":5,"price":0.3,"timestamp":1700000000,"outcome":"No"}]
        """.data(using: .utf8)!
        let dtos = try JSONDecoder.polymarket.decode([ActivityTradeDTO].self, from: json)
        let trades = MarketMapper.trades(from: dtos)
        XCTAssertEqual(trades.first?.side, .sell)
    }

    func test_activityTradeDTO_toleratesMissingOrMistypedFields() throws {
        let json = #"[{"proxyWallet":"0xabc"}]"#.data(using: .utf8)!
        let dtos = try JSONDecoder.polymarket.decode([ActivityTradeDTO].self, from: json)
        let trades = MarketMapper.trades(from: dtos)
        let trade = try XCTUnwrap(trades.first)
        XCTAssertEqual(trade.size, 0)
        XCTAssertEqual(trade.price, 0)
        XCTAssertEqual(trade.outcome, "")
        XCTAssertEqual(trade.side, .buy) // absent side degrades to buy, never throws

        // Mistyped timestamp (string instead of number) must not fail the decode.
        let mistyped = #"[{"proxyWallet":"0xabc","timestamp":"not-a-number"}]"#.data(using: .utf8)!
        let mistypedDTOs = try JSONDecoder.polymarket.decode([ActivityTradeDTO].self, from: mistyped)
        XCTAssertEqual(mistypedDTOs.first?.timestamp, 0)
    }
}
