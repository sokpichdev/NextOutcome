import XCTest
@testable import PortfolioDomain

final class PortfolioTests: XCTestCase {
    func test_walletAddress_validatesAndLowercases() {
        XCTAssertEqual(WalletAddress("0x" + String(repeating: "Ab", count: 20))?.value,
                       "0x" + String(repeating: "ab", count: 20))
        XCTAssertNil(WalletAddress("0x123"))          // too short
        XCTAssertNil(WalletAddress("notanaddress"))   // no 0x
        XCTAssertNil(WalletAddress("0x" + String(repeating: "zz", count: 20))) // non-hex
    }

    func test_portfolio_aggregatesPnl() {
        let portfolio = Portfolio(address: "0xabc", value: 110, positions: [
            position(cashPnl: 5), position(cashPnl: 5),
        ])
        XCTAssertEqual(portfolio.totalCashPnl, 10)
        // basis = 110 - 10 = 100 → 10%
        XCTAssertEqual(portfolio.totalPercentPnl, 10)
    }

    func test_fetchPortfolio_combinesValueAndPositions() async throws {
        let repo = StubRepo(value: 42, positions: [position(cashPnl: 1)])
        let useCase = FetchPortfolioUseCase(repository: repo)
        let portfolio = try await useCase.execute(address: "0xabc")
        XCTAssertEqual(portfolio.value, 42)
        XCTAssertEqual(portfolio.positions.count, 1)
    }

    private func position(cashPnl: Decimal) -> Position {
        Position(id: "t", conditionId: "c", title: "M", slug: "m", outcome: "Yes",
                 iconURL: nil, size: 10, avgPrice: 0.5, curPrice: 0.6,
                 currentValue: 6, cashPnl: cashPnl, percentPnl: 20, redeemable: false)
    }
}

private struct StubRepo: PortfolioRepository {
    let value: Decimal
    let positions: [Position]
    func positions(address: String) async throws -> [Position] { positions }
    func value(address: String) async throws -> Decimal { value }
}
