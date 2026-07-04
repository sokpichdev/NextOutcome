//
//  DateParsingTests.swift
//  NextOutcome
//

import XCTest
@testable import MarketsData

final class DateParsingTests: XCTestCase {
    func test_parse_iso8601() {
        XCTAssertNotNil(DateParsing.parse("2026-07-02T16:05:05Z"))
        XCTAssertNotNil(DateParsing.parse("2026-07-02T16:05:05.93448Z"))
    }

    func test_parse_gammaGameStartTime_spaceSeparated() throws {
        // Gamma's `gameStartTime` format ("2026-06-11 19:00:00+00") isn't ISO8601;
        // without the DateFormatter fallback every kickoff date parsed to nil.
        let date = try XCTUnwrap(DateParsing.parse("2026-06-11 19:00:00+00"))
        XCTAssertEqual(date, ISO8601DateFormatter().date(from: "2026-06-11T19:00:00Z"))
    }

    func test_parse_invalidOrNil_isNil() {
        XCTAssertNil(DateParsing.parse(nil))
        XCTAssertNil(DateParsing.parse("not a date"))
    }
}
