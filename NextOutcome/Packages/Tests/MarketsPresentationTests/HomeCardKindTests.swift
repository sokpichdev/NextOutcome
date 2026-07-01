import XCTest
@testable import MarketsPresentation
import MarketsDomain

private func mkOutcome(_ title: String, _ price: Double) -> Outcome {
    Outcome(id: title, title: title, price: Decimal(price))
}
private func mkMarket(id: String, outcomes: [Outcome]) -> Market {
    Market(id: id, question: id, slug: id, outcomes: outcomes,
           volume: 0, liquidity: 0, endDate: nil, isResolved: false, imageURL: nil)
}
private func mkEvent(markets: [Market], tags: [String] = [], image: URL? = nil) -> Event {
    Event(id: "e", title: "t", slug: "s", markets: markets, volume: 0, imageURL: image,
          tags: tags.map { Tag(id: $0, label: $0, slug: $0.lowercased()) })
}

final class HomeCardKindTests: XCTestCase {
    func test_liveUpDown_whenOutcomesAreUpDownAndCryptoTag() {
        let m = mkMarket(id: "btc", outcomes: [mkOutcome("Up", 0.51), mkOutcome("Down", 0.49)])
        let e = mkEvent(markets: [m], tags: ["Crypto"])
        XCTAssertEqual(HomeCardKind.classify(e), .liveUpDown)
    }

    func test_news_whenSingleBinaryMarketWithImageAndBreakingTag() {
        let m = mkMarket(id: "n", outcomes: [mkOutcome("Yes", 0.9), mkOutcome("No", 0.1)])
        let e = mkEvent(markets: [m], tags: ["Breaking"], image: URL(string: "https://x/y.png"))
        XCTAssertEqual(HomeCardKind.classify(e), .news)
    }

    func test_multiOutcome_whenTwoOrMoreMarkets() {
        let e = mkEvent(markets: [mkMarket(id: "a", outcomes: []), mkMarket(id: "b", outcomes: [])])
        XCTAssertEqual(HomeCardKind.classify(e), .multiOutcome)
    }

    func test_standard_fallback() {
        let m = mkMarket(id: "s", outcomes: [mkOutcome("Yes", 0.5), mkOutcome("No", 0.5)])
        XCTAssertEqual(HomeCardKind.classify(mkEvent(markets: [m])), .standard)
    }

    func test_classifyNeverReturnsHero() {
        let e = mkEvent(markets: [mkMarket(id: "a", outcomes: []), mkMarket(id: "b", outcomes: [])],
                        tags: ["Sports"])
        XCTAssertNotEqual(HomeCardKind.classify(e), .hero)
    }

    func test_isSports_true_whenSportsOrSoccerTag() {
        XCTAssertTrue(HomeCardKind.isSports(mkEvent(markets: [], tags: ["Soccer"])))
        XCTAssertFalse(HomeCardKind.isSports(mkEvent(markets: [], tags: ["Politics"])))
    }
}
