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
}
