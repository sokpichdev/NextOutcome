import XCTest
@testable import PortfolioData
import PortfolioDomain

final class LeaderboardDecodingTests: XCTestCase {
    /// A captured `/v1/leaderboard?category=esports` row (July 2026 shape).
    private let categoryRowJSON = Data("""
    [{"rank":"1","proxyWallet":"0x4be1fa92e6ceaf886aac0bbec3be6c527133aa70","userName":"Eztennis",
      "xUsername":"polyEztennis","verifiedBadge":false,"vol":9206066.651811,"pnl":940701.4076569332,
      "profileImage":""}]
    """.utf8)

    func test_decode_categoryShape() throws {
        let rows = try JSONDecoder().decode([LeaderboardEntryDTO].self, from: categoryRowJSON)
        let row = try XCTUnwrap(rows.first)
        XCTAssertEqual(row.proxyWallet, "0x4be1fa92e6ceaf886aac0bbec3be6c527133aa70")
        XCTAssertEqual(row.name, "Eztennis")
        XCTAssertEqual(row.xUsername, "polyEztennis")
        XCTAssertFalse(row.verifiedBadge)
        XCTAssertEqual(row.pnl.map { NSDecimalNumber(decimal: $0).doubleValue ?? 0 } ?? 0, 940701.4076569332, accuracy: 0.01)
        XCTAssertEqual(row.vol.map { NSDecimalNumber(decimal: $0).doubleValue ?? 0 } ?? 0, 9206066.651811, accuracy: 0.01)
    }

    func test_mapper_prefersMetricAmount_andEmptyAvatarDropped() throws {
        let rows = try JSONDecoder().decode([LeaderboardEntryDTO].self, from: categoryRowJSON)
        let profit = LeaderboardMapper.entry(from: rows[0], rank: 1, metric: .profit)
        XCTAssertEqual(profit.name, "Eztennis")
        XCTAssertEqual(profit.xUsername, "polyEztennis")
        XCTAssertNil(profit.profileImageURL)
        XCTAssertEqual(NSDecimalNumber(decimal: profit.amount).doubleValue, 940701.4076569332, accuracy: 0.01)
        let volume = LeaderboardMapper.entry(from: rows[0], rank: 1, metric: .volume)
        XCTAssertEqual(NSDecimalNumber(decimal: volume.amount).doubleValue, 9206066.651811, accuracy: 0.01)
    }

    func test_leaderboardQuery_categoryUsesNewParams() {
        let query = DataPortfolioRepository.leaderboardQuery(
            metric: .profit, window: .month, category: "esports", limit: 20
        )
        XCTAssertEqual(query, [
            "timePeriod": "MONTH", "orderBy": "PNL", "category": "esports", "limit": "20",
        ])
    }

    func test_leaderboardQuery_globalKeepsLegacyParams() {
        let query = DataPortfolioRepository.leaderboardQuery(
            metric: .volume, window: .week, category: nil, limit: 10
        )
        XCTAssertEqual(query, ["rankBy": "volume", "window": "7d", "limit": "10"])
    }
}
