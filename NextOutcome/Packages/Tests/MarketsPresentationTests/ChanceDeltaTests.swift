import XCTest
@testable import MarketsPresentation

final class ChanceDeltaTests: XCTestCase {
    func test_up_positiveDelta() {
        let r = ChanceDelta.format(Decimal(9))
        XCTAssertEqual(r?.text, "▲ 9%")
        XCTAssertEqual(r?.direction, .up)
    }
    func test_down_negativeDelta() {
        let r = ChanceDelta.format(Decimal(-4))
        XCTAssertEqual(r?.text, "▼ 4%")
        XCTAssertEqual(r?.direction, .down)
    }
    func test_flat_zero() {
        let r = ChanceDelta.format(Decimal(0))
        XCTAssertEqual(r?.direction, .flat)
        XCTAssertEqual(r?.text, "0%")
    }
    func test_nil_isHidden() {
        XCTAssertNil(ChanceDelta.format(nil))
    }
    func test_rounds_toWholePercent() {
        XCTAssertEqual(ChanceDelta.format(Decimal(string: "8.6"))?.text, "▲ 9%")
    }
}
