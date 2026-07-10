import XCTest
@testable import DesignSystem

final class SideMenuDrawerTests: XCTestCase {
    func test_primaryItems_areLeaderboardRewardsAPIs() {
        XCTAssertEqual(
            SideMenuDrawer.primaryItems.map(\.title),
            ["Leaderboard", "Rewards", "APIs"]
        )
    }

    func test_secondaryItems_matchScreenshot() {
        XCTAssertEqual(
            SideMenuDrawer.secondaryItems.map(\.title),
            ["Accuracy", "Support", "Status", "Documentation", "Help Center", "Terms of Use"]
        )
    }

    func test_themeToggleGlyph_showsSun_whenCurrentlyDark() {
        XCTAssertEqual(SideMenuDrawer.themeToggleGlyph(isDarkMode: true), "sun.max.fill")
    }

    func test_themeToggleGlyph_showsMoon_whenCurrentlyLight() {
        XCTAssertEqual(SideMenuDrawer.themeToggleGlyph(isDarkMode: false), "moon.fill")
    }
}
