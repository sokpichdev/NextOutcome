//
//  WorldCupUITests.swift
//  NextOutcome
//
//  Created by Sok Pich on 19/07/2026.
//
//  TC-061: the World Cup hub loads from its rail chip with schedule/game
//  content. (The deeper logo-vs-card tap behavior is covered by the existing
//  testWorldCupGameCard_tapTeamLogo_opensProfile_tapElsewhere_opensEvent.)
//

import XCTest

final class WorldCupUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// TC-061: tap the World Cup rail chip; the hub renders in place with
    /// scrollable content and market cards.
    @MainActor
    func testWorldCupHubLoads() throws {
        let app = XCUIApplication.launched()

        let chip = app.buttons["World Cup"]
        assertAppears(chip, timeout: UIWait.ui, "World Cup chip should be pinned on the rail")
        chip.tap()

        assertAppears(app.anyVolumeLabel, timeout: UIWait.firstLoad,
                      "World Cup hub should load game/prop cards")
        XCTAssertFalse(app.backButton.exists, "The hub swaps in place — no push")
        attachScreenshot(of: app, named: "World Cup hub — top")

        // The hub is long (bracket, map, schedule, props) — scroll through it.
        app.swipeUp()
        app.swipeUp()
        attachScreenshot(of: app, named: "World Cup hub — scrolled")

        // Pull-to-refresh at the top must keep content.
        app.swipeDown()
        app.swipeDown()
        app.pullToRefresh()
        assertAppears(app.anyVolumeLabel, timeout: UIWait.load,
                      "World Cup content should survive a refresh")
    }
}
