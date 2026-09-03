import XCTest
@testable import DesignSystem

final class ScreenshotModeTests: XCTestCase {

    func test_isActive_isFalse_whenFlagAbsent() {
        XCTAssertFalse(ScreenshotMode.isActive(in: ["NextOutcome", "-preselectCategory", "crypto", "123"]))
    }

    func test_isActive_isTrue_whenFlagPresent() {
        XCTAssertTrue(ScreenshotMode.isActive(in: ["NextOutcome", "-screenshotMode"]))
    }

    func test_isActive_isTrue_whenFlagAppearsAlongsideOtherArguments() {
        XCTAssertTrue(ScreenshotMode.isActive(in: ["NextOutcome", "-preselectCategory", "crypto", "123", "-screenshotMode"]))
    }

    func test_flag_matchesTheLaunchArgumentSpelling() {
        XCTAssertEqual(ScreenshotMode.flag, "-screenshotMode")
    }
}
