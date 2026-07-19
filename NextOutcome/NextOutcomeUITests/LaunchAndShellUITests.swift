//
//  LaunchAndShellUITests.swift
//  NextOutcome
//
//  Created by Sok Pich on 19/07/2026.
//

//  TC-001…TC-003: cold launch lands on Home with the full shell chrome —
//  tab bar, NOTopBar (Rewards / Notifications / Account menu), category rail.
//

import XCTest

final class LaunchAndShellUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// TC-001: the app launches to the Home tab with the tab bar, the
    /// NextOutcome top bar, and the pinned category rail all visible.
    @MainActor
    func testAppLaunchesToHome() throws {
        let app = XCUIApplication.launched()

        // Tab bar with exactly four tabs.
        assertAppears(app.tabBars.firstMatch, timeout: UIWait.ui,
                      "Expected the root tab bar after launch")
        XCTAssertEqual(app.tabBars.buttons.count, 4,
                       "Expected exactly Home, Search, Breaking, Portfolio tabs")
        XCTAssertTrue(app.homeTab.isSelected, "Home should be the initial tab")

        // Pinned category rail chips (fixed order per HubTab.pinned).
        for chip in ["Trending", "World Cup", "Breaking", "Politics", "Sports"] {
            assertAppears(app.buttons[chip], timeout: UIWait.ui,
                          "Expected the pinned '\(chip)' category chip on Home")
        }

        // The Trending feed eventually shows at least one real market card.
        assertAppears(app.anyVolumeLabel, timeout: UIWait.firstLoad,
                      "Expected the Trending feed to load at least one card with a Vol label")
        attachScreenshot(of: app, named: "Launch — Home / Trending")
    }

    /// TC-003: the NOTopBar chrome buttons exist and are hittable. These are
    /// the only accessibilityLabels defined in the shell today.
    @MainActor
    func testTopBarButtonsExist() throws {
        let app = XCUIApplication.launched()

        for label in ["Rewards", "Notifications", "Account menu"] {
            let button = app.buttons[label]
            assertAppears(button, timeout: UIWait.ui,
                          "Expected the '\(label)' top-bar button")
            XCTAssertTrue(button.isHittable, "'\(label)' should be tappable")
        }
    }

    /// TC-002: launch-time metric, mirroring the template test that already
    /// exists — kept here so this suite is self-contained if run alone.
    @MainActor
    func testShellLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
