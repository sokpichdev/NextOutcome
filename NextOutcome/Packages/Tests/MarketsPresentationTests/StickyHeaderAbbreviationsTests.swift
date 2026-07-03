import XCTest
import MarketsDomain
@testable import MarketsPresentation

final class StickyHeaderAbbreviationsTests: XCTestCase {
    private func market(_ id: String, groupItemTitle: String?, sportsMarketType: String?) -> Market {
        Market(id: id, question: "\(id) question", slug: id,
               outcomes: [Outcome(id: "y", title: "Yes", price: Decimal(0.5)),
                          Outcome(id: "n", title: "No", price: Decimal(0.5))],
               volume: 0, liquidity: 0, endDate: nil, isResolved: false, imageURL: nil,
               sportsMarketType: sportsMarketType, groupItemTitle: groupItemTitle)
    }

    /// Non-alternating market order — moneyline markets aren't adjacent in the raw array —
    /// should still pair the two moneyline markets (A vs B), not A vs A's own spread.
    func testNonAlternatingOrderingPairsMoneylineMarkets() {
        let markets = [
            market("a-ml", groupItemTitle: "Argentina", sportsMarketType: "moneyline"),
            market("a-sp", groupItemTitle: "Argentina", sportsMarketType: "spreads"),
            market("b-ml", groupItemTitle: "Cabo Verde", sportsMarketType: "moneyline")
        ]

        let result = StickyHeaderAbbreviations.stickyAbbreviations(for: markets)

        // Should pair the two moneyline markets (Argentina vs Cabo Verde), not the
        // raw second array element (Argentina's own spread market).
        XCTAssertEqual(result?.left, "ARG")
        XCTAssertEqual(result?.right, "CAB")
    }

    func testEmptyGroupItemTitleFallsThroughToFallback() {
        let markets = [
            market("a-ml", groupItemTitle: "Team A", sportsMarketType: "moneyline"),
            market("b-ml", groupItemTitle: "", sportsMarketType: "moneyline")
        ]

        let result = StickyHeaderAbbreviations.stickyAbbreviations(for: markets)

        XCTAssertNil(result)
    }

    func testNoMoneylineGroupReturnsNil() {
        let markets = [
            market("a-sp", groupItemTitle: "Team A", sportsMarketType: "spreads"),
            market("b-sp", groupItemTitle: "Team B", sportsMarketType: "spreads")
        ]

        let result = StickyHeaderAbbreviations.stickyAbbreviations(for: markets)

        XCTAssertNil(result)
    }

    func testSingleMoneylineMarketReturnsNil() {
        let markets = [
            market("a-ml", groupItemTitle: "Team A", sportsMarketType: "moneyline")
        ]

        let result = StickyHeaderAbbreviations.stickyAbbreviations(for: markets)

        XCTAssertNil(result)
    }
}
