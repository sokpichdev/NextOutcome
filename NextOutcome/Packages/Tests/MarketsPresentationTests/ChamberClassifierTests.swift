import XCTest
@testable import MarketsPresentation

final class ChamberClassifierTests: XCTestCase {
    func test_houseTitle_resolvesChamberAndDistrictState() {
        let result = ChamberClassifier.classify(title: "CA-22 House Election Winner")
        XCTAssertEqual(result.chamber, .house)
        XCTAssertEqual(result.stateCode, "ca")
    }

    func test_senateTitle_resolvesChamberAndFullStateName() {
        let result = ChamberClassifier.classify(title: "California Senate Election Winner")
        XCTAssertEqual(result.chamber, .senate)
        XCTAssertEqual(result.stateCode, "ca")
    }

    func test_governorTitle_resolvesChamberAndFullStateName() {
        let result = ChamberClassifier.classify(title: "New Hampshire Governor Election Winner")
        XCTAssertEqual(result.chamber, .governor)
        XCTAssertEqual(result.stateCode, "nh")
    }

    /// Regression test: real Gamma data carries incidental trailing whitespace on some
    /// titles (e.g. "Nebraska Senate Election Winner  ") — must still classify correctly.
    func test_trailingWhitespace_stillClassifies() {
        let result = ChamberClassifier.classify(title: "Nebraska Senate Election Winner  ")
        XCTAssertEqual(result.chamber, .senate)
        XCTAssertEqual(result.stateCode, "ne")
    }

    func test_aggregateThematicTitle_classifiesAsOther() {
        XCTAssertEqual(ChamberClassifier.classify(title: "Which party will win the Senate in 2026?").chamber, .other)
        XCTAssertEqual(ChamberClassifier.classify(title: "Balance of Power: 2026 Midterms").chamber, .other)
        XCTAssertEqual(ChamberClassifier.classify(title: "Republican Senate seats after the 2026 midterm elections?").chamber, .other)
        XCTAssertEqual(ChamberClassifier.classify(title: "How many Republican Governors after the 2026 midterm elections?").chamber, .other)
    }

    func test_unrecognizedStateName_resolvesChamberWithNilState() {
        let result = ChamberClassifier.classify(title: "Atlantis Senate Election Winner")
        XCTAssertEqual(result.chamber, .senate)
        XCTAssertNil(result.stateCode)
    }
}
