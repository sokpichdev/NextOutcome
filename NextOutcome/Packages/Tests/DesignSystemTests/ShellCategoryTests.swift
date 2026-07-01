import XCTest
@testable import DesignSystem

final class ShellCategoryTests: XCTestCase {
    func test_allCasesInScreenshotOrder() {
        XCTAssertEqual(
            ShellCategory.allCases,
            [.trending, .worldCup, .breaking, .politics, .sports]
        )
    }

    func test_titles() {
        XCTAssertEqual(ShellCategory.worldCup.title, "World Cup")
        XCTAssertEqual(ShellCategory.trending.title, "Trending")
    }
}
