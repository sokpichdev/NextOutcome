import XCTest
import MarketsDomain
@testable import MarketsPresentation

final class PartyControlSummaryTests: XCTestCase {
    private func market(_ title: String, yes: Double) -> Market {
        Market(id: title, question: title, slug: title,
               outcomes: [Outcome(id: "\(title)-yes", title: "Yes", price: Decimal(yes)),
                          Outcome(id: "\(title)-no", title: "No", price: Decimal(1 - yes))],
               volume: 0, liquidity: 0, endDate: nil, isResolved: false, imageURL: nil,
               groupItemTitle: title)
    }

    private func event(markets: [Market]) -> Event {
        Event(id: "e", title: "Which party will win the Senate in 2026?", slug: "s", markets: markets, volume: 0, imageURL: nil)
    }

    func test_republicanLeading_namesRepublicans() {
        let e = event(markets: [market("Democratic", yes: 0.445), market("Republican", yes: 0.555)])
        let summary = PartyControlSummary.summary(for: e)
        XCTAssertEqual(summary?.leadingParty, "Republicans")
        XCTAssertEqual(summary?.percent, 0.555)
    }

    func test_democratLeading_namesDemocrats() {
        let e = event(markets: [market("Democrat", yes: 0.84), market("Republican", yes: 0.16)])
        let summary = PartyControlSummary.summary(for: e)
        XCTAssertEqual(summary?.leadingParty, "Democrats")
        XCTAssertEqual(summary?.percent, 0.84)
    }

    func test_nilEvent_returnsNil() {
        XCTAssertNil(PartyControlSummary.summary(for: nil))
    }

    func test_noPartyMarkets_returnsNil() {
        let e = event(markets: [market("Xavier Becerra", yes: 0.92), market("Steve Hilton", yes: 0.08)])
        XCTAssertNil(PartyControlSummary.summary(for: e))
    }
}
