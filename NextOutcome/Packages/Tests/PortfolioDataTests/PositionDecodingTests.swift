import XCTest
import PortfolioDomain
@testable import PortfolioData

final class PositionDecodingTests: XCTestCase {
    func test_positionDTO_decodesNumericFields() throws {
        let json = """
        {
          "asset": "t1", "conditionId": "0xcond", "title": "Will X?",
          "slug": "will-x", "outcome": "Yes", "icon": "https://x/i.png",
          "size": 12.5, "avgPrice": 0.42, "curPrice": 0.61,
          "currentValue": 7.63, "cashPnl": 2.37, "percentPnl": 45.2,
          "redeemable": false
        }
        """.data(using: .utf8)!

        let dto = try JSONDecoder.polymarket.decode(PositionDTO.self, from: json)
        let position = PositionMapper.position(from: dto)

        XCTAssertEqual(position.id, "t1")
        XCTAssertEqual(position.size, Decimal(string: "12.5"))
        XCTAssertEqual(position.cashPnl, Decimal(string: "2.37"))
        XCTAssertTrue(position.isProfitable)
    }

    func test_positionDTO_toleratesStringNumbersAndMissing() throws {
        let json = #"{"asset": "t2", "size": "3", "cashPnl": "-1.5"}"#.data(using: .utf8)!
        let dto = try JSONDecoder.polymarket.decode(PositionDTO.self, from: json)
        XCTAssertEqual(dto.size, 3)
        XCTAssertEqual(dto.cashPnl, Decimal(string: "-1.5"))
        XCTAssertEqual(dto.avgPrice, 0)   // missing → 0
        XCTAssertFalse(dto.redeemable)
    }

    func test_activityDTO_mapsTradeSideToKind() throws {
        let json = """
        { "type": "TRADE", "side": "SELL", "title": "Will X?", "outcome": "Yes",
          "size": 10, "usdcSize": 6.1, "price": 0.61, "timestamp": 1699999999,
          "transactionHash": "0xhash" }
        """.data(using: .utf8)!
        let dto = try JSONDecoder.polymarket.decode(ActivityDTO.self, from: json)
        let activity = ActivityMapper.activity(from: dto, index: 0)
        XCTAssertEqual(activity.kind, .sell)
        XCTAssertEqual(activity.usdcSize, Decimal(string: "6.1"))
        XCTAssertTrue(activity.isCredit)
    }

    func test_activityMapper_mapsLifecycleTypes() {
        XCTAssertEqual(ActivityMapper.kind(type: "REDEEM", side: nil), .redeem)
        XCTAssertEqual(ActivityMapper.kind(type: "SPLIT", side: nil), .split)
        XCTAssertEqual(ActivityMapper.kind(type: "TRADE", side: "BUY"), .buy)
        XCTAssertEqual(ActivityMapper.kind(type: "WEIRD", side: nil), .other)
    }

    func test_closedPositionDTO_decodes() throws {
        let json = """
        { "conditionId": "0xc", "title": "Won?", "outcome": "Yes",
          "realizedPnl": 12.5, "percentRealizedPnl": 30, "timestamp": 1699999999 }
        """.data(using: .utf8)!
        let dto = try JSONDecoder.polymarket.decode(ClosedPositionDTO.self, from: json)
        let closed = LeaderboardMapper.closedPosition(from: dto, index: 0)
        XCTAssertEqual(closed.realizedPnl, Decimal(string: "12.5"))
        XCTAssertTrue(closed.isProfitable)
    }

    func test_leaderboardEntry_fallsBackToWalletName() throws {
        let json = #"{"proxyWallet": "0x1234567890abcdef", "volume": 5000}"#.data(using: .utf8)!
        let dto = try JSONDecoder.polymarket.decode(LeaderboardEntryDTO.self, from: json)
        let entry = LeaderboardMapper.entry(from: dto, rank: 1)
        XCTAssertEqual(entry.name, "0x1234…cdef")   // shortened wallet
        XCTAssertEqual(entry.amount, 5000)          // picked up from `volume`
        XCTAssertEqual(entry.rank, 1)
    }
}
