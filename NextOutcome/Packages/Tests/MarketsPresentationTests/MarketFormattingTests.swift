import XCTest
@testable import MarketsPresentation

final class MarketFormattingTests: XCTestCase {
    func test_tradeLabel_computesPayoutFor100Dollars() {
        XCTAssertEqual(MarketFormatting.tradeLabel(price: 0.56), "Trade $100 → $179")
        XCTAssertEqual(MarketFormatting.tradeLabel(price: 0.5), "Trade $100 → $200")
    }

    func test_tradeLabel_zeroOrOne_fallsBackToPlainTrade() {
        XCTAssertEqual(MarketFormatting.tradeLabel(price: 0), "Trade")
        XCTAssertEqual(MarketFormatting.tradeLabel(price: 1), "Trade")
    }
}
