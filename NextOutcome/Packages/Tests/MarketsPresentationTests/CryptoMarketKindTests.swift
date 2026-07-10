import XCTest
@testable import MarketsPresentation
import MarketsDomain

final class CryptoMarketKindTests: XCTestCase {
    private func market(
        id: String = "m1",
        question: String = "Q",
        groupItemTitle: String? = nil,
        outcomeTitles: [String] = ["Yes", "No"]
    ) -> Market {
        let outcomes = outcomeTitles.enumerated().map { index, title in
            Outcome(id: "\(id)-\(index)", title: title, price: Decimal(0.5))
        }
        return Market(
            id: id, question: question, slug: id, outcomes: outcomes,
            volume: 0, liquidity: 0, endDate: nil, isResolved: false,
            imageURL: nil, groupItemTitle: groupItemTitle
        )
    }

    private func event(title: String, markets: [Market]) -> Event {
        Event(id: "e1", title: title, slug: "e1", markets: markets, volume: 0, imageURL: nil)
    }

    func test_classify_upDown() {
        let e = event(title: "BTC Up or Down 5m", markets: [market(outcomeTitles: ["Up", "Down"])])
        XCTAssertEqual(CryptoMarketKind.classify(e), .upDown)
    }

    func test_classify_priceRange() {
        let e = event(title: "Bitcoin price on July 10?", markets: [
            market(id: "m1", groupItemTitle: "64,000-66,000"),
            market(id: "m2", groupItemTitle: "62,000-64,000"),
        ])
        XCTAssertEqual(CryptoMarketKind.classify(e), .priceRange)
    }

    func test_classify_aboveBelow() {
        let e = event(title: "Bitcoin above ___ on July 10?", markets: [
            market(id: "m1", groupItemTitle: "52,000"),
            market(id: "m2", groupItemTitle: "54,000"),
        ])
        XCTAssertEqual(CryptoMarketKind.classify(e), .aboveBelow)
    }

    func test_classify_hitPrice() {
        let e = event(title: "What price will Bitcoin hit in July?", markets: [
            market(id: "m1", groupItemTitle: "65,000"),
            market(id: "m2", groupItemTitle: "62,500"),
        ])
        XCTAssertEqual(CryptoMarketKind.classify(e), .hitPrice)
    }

    func test_classify_other_whenNoShapeMatches() {
        let e = event(title: "Some random crypto market", markets: [market(id: "m1")])
        XCTAssertEqual(CryptoMarketKind.classify(e), .other)
    }

    func test_classify_priceRange_winsOverAboveBelowTitle_whenGroupItemTitleIsARange() {
        // Title says "above" but groupItemTitle is a range — the range check runs first
        // and wins, since a range shape is unambiguous evidence.
        let e = event(title: "Bitcoin above/below range on July 10?", markets: [
            market(id: "m1", groupItemTitle: "64,000-66,000"),
        ])
        XCTAssertEqual(CryptoMarketKind.classify(e), .priceRange)
    }

    func test_classify_aboveBelow_falseForEmptyMarkets() {
        let e = event(title: "Bitcoin above ___ on July 10?", markets: [])
        XCTAssertEqual(CryptoMarketKind.classify(e), .other)
    }
}
