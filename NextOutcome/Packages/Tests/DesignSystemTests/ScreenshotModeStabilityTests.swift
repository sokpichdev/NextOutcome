import XCTest
import SwiftUI
@testable import DesignSystem

final class ScreenshotModeStabilityTests: XCTestCase {

    func test_shimmerAnimation_isNil_whenScreenshotModeActive() {
        XCTAssertNil(Skeleton.shimmerAnimation(screenshotMode: true))
    }

    func test_shimmerAnimation_isPresent_normally() {
        XCTAssertNotNil(Skeleton.shimmerAnimation(screenshotMode: false))
    }
}
