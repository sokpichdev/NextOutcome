//
//  DrawerUITests.swift
//  NextOutcome
//
//  Created by Sok Pich on 19/07/2026.
//
//  TC-120, TC-121: the side menu drawer — opened from the top bar's
//  "Account menu" avatar. Lists Leaderboard / Rewards / APIs plus the
//  secondary items, a theme toggle, and Logout; the Leaderboard item pushes
//  the top-traders screen.
//

import XCTest

final class DrawerUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func openDrawer(_ app: XCUIApplication) {
        let avatar = app.buttons["Account menu"]
        assertAppears(avatar, timeout: UIWait.load, "Top-bar avatar should exist")
        avatar.tap()
        assertAppears(app.buttons["Logout"], timeout: UIWait.ui,
                      "Drawer should slide in (Logout visible)")
    }

    /// TC-120: the drawer opens, lists every menu item, and closes by
    /// tapping the dimmed scrim on the right.
    @MainActor
    func testDrawerOpensListsItemsAndCloses() throws {
        let app = XCUIApplication.launched()
        openDrawer(app)

        for item in ["Leaderboard", "Rewards", "APIs",
                     "Accuracy", "Support", "Status",
                     "Documentation", "Help Center", "Terms of Use",
                     "Logout"] {
            XCTAssertTrue(app.buttons[item].exists || app.staticTexts[item].exists,
                          "Drawer should list '\(item)'")
        }
        attachScreenshot(of: app, named: "Drawer — open")

        // Close by tapping the content scrim on the far right.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        XCTAssertTrue(app.buttons["Trending"].waitForExistence(timeout: UIWait.ui),
                      "Tapping the scrim should close the drawer back to Home")
    }

    /// TC-121: the drawer's Leaderboard item opens the top-traders screen
    /// with its profit/volume segment toggle.
    @MainActor
    func testDrawerLeaderboardOpens() throws {
        let app = XCUIApplication.launched()
        openDrawer(app)

        let leaderboardItem = app.buttons["Leaderboard"].exists
            ? app.buttons["Leaderboard"]
            : app.staticTexts["Leaderboard"]
        leaderboardItem.tap()

        // The leaderboard screen shows trader rows; give the data-api time.
        let profit = app.buttons["Profit"]
        let volume = app.buttons["Volume"]
        let opened = profit.waitForExistence(timeout: UIWait.firstLoad)
            || volume.exists
            || app.backButton.waitForExistence(timeout: UIWait.ui)
        XCTAssertTrue(opened, "Leaderboard screen should open from the drawer")
        attachScreenshot(of: app, named: "Leaderboard — from drawer")

        if volume.exists {
            volume.tap()
            attachScreenshot(of: app, named: "Leaderboard — volume ranking")
        }
    }
}
