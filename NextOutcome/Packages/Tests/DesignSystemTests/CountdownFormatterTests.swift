import XCTest
@testable import DesignSystem

final class CountdownFormatterTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_000_000)

    func testUnderAnHourIsMinutesSeconds() {
        let end = now.addingTimeInterval(227) // 3m47s
        XCTAssertEqual(CountdownFormatter.string(until: end, now: now), "3:47")
    }
    func testOverAnHourIsHoursMinutes() {
        let end = now.addingTimeInterval(4_320) // 1h12m
        XCTAssertEqual(CountdownFormatter.string(until: end, now: now), "1h 12m")
    }
    func testPastEndClampsToZero() {
        XCTAssertEqual(CountdownFormatter.string(until: now.addingTimeInterval(-5), now: now), "0:00")
    }
}
