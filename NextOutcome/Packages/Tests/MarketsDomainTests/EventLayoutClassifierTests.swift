import XCTest
@testable import MarketsDomain

final class EventLayoutClassifierTests: XCTestCase {
    private func market(id: String, endDate: Date?) -> Market {
        Market(id: id, question: id, slug: id,
               outcomes: [Outcome(id: "\(id)-yes", title: "Yes", price: 0.5),
                          Outcome(id: "\(id)-no", title: "No", price: 0.5)],
               volume: 0, liquidity: 0, endDate: endDate, isResolved: false, imageURL: nil)
    }

    /// World Cup Winner-style: every candidate market shares the tournament's one
    /// resolution date — a single overlaid chart makes sense.
    func test_sameEndDateAcrossMarkets_classifiesAsChart() {
        let date = Date()
        let markets = [
            market(id: "spain", endDate: date),
            market(id: "france", endDate: date),
            market(id: "argentina", endDate: date),
        ]

        XCTAssertEqual(EventLayoutClassifier.classify(markets), .chart)
    }

    /// "GPT-5.6 released by…?"-style: each deadline market resolves on its own date — a
    /// scrollable date-ladder list makes sense instead of one chart.
    func test_distinctEndDatesAcrossMarkets_classifiesAsDateLadder() {
        let markets = [
            market(id: "july-6", endDate: Date(timeIntervalSince1970: 1)),
            market(id: "july-7", endDate: Date(timeIntervalSince1970: 2)),
            market(id: "july-8", endDate: Date(timeIntervalSince1970: 3)),
        ]

        XCTAssertEqual(EventLayoutClassifier.classify(markets), .dateLadder)
    }

    func test_singleMarket_classifiesAsChart() {
        let markets = [market(id: "only", endDate: Date())]

        XCTAssertEqual(EventLayoutClassifier.classify(markets), .chart)
    }

    /// Markets with no end date at all (nil) shouldn't be miscounted as "distinct dates."
    func test_noEndDates_classifiesAsChart() {
        let markets = [market(id: "a", endDate: nil), market(id: "b", endDate: nil)]

        XCTAssertEqual(EventLayoutClassifier.classify(markets), .chart)
    }

    func test_empty_classifiesAsChart() {
        XCTAssertEqual(EventLayoutClassifier.classify([]), .chart)
    }
}
