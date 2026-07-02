import XCTest
@testable import MarketsPresentation
import OrderbookDomain

final class ChartTimeframeTests: XCTestCase {
    func test_titles() {
        XCTAssertEqual(ChartTimeframe.allCases.map(\.title), ["1H", "1D", "1W", "1M", "MAX"])
    }
    func test_intervalMapping() {
        XCTAssertEqual(ChartTimeframe.h1.interval, .oneHour)
        XCTAssertEqual(ChartTimeframe.d1.interval, .oneDay)
        XCTAssertEqual(ChartTimeframe.w1.interval, .oneWeek)
        XCTAssertEqual(ChartTimeframe.m1.interval, .oneMonth)
        XCTAssertEqual(ChartTimeframe.max.interval, .max)
    }
}
