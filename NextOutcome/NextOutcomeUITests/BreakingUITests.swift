//
//  BreakingUITests.swift
//  NextOutcome
//
//  Created by Sok Pich on 19/07/2026.
//
//  TC-070, TC-071: the Breaking tab (biggest 24h movers). Mover rows carry a
//  dynamic accessibility label of the form "Up/Down N percent over 24 hours",
//  which is the stable structural anchor.
//

import XCTest

final class BreakingUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func moverRow(in app: XCUIApplication) -> XCUIElement {
        app.staticTexts
            .matching(NSPredicate(format: "label CONTAINS[c] %@", "percent over 24 hours"))
            .firstMatch
    }

    /// TC-070: the Breaking tab lists movers, scrolls, and refreshes.
    @MainActor
    func testBreakingMoversLoad() throws {
        let app = XCUIApplication.launched()
        app.breakingTab.tap()

        assertAppears(moverRow(in: app), timeout: UIWait.firstLoad,
                      "Breaking should list at least one 24h mover")
        attachScreenshot(of: app, named: "Breaking — movers loaded")

        app.swipeUp()
        assertAppears(moverRow(in: app), timeout: UIWait.ui,
                      "Movers should still be present after scrolling")

        app.swipeDown()
        app.pullToRefresh()
        assertAppears(moverRow(in: app), timeout: UIWait.load,
                      "Movers should repopulate after pull-to-refresh")
    }

    /// TC-071: tapping a mover pushes its detail screen and Back returns.
    @MainActor
    func testMoverPushesDetail() throws {
        let app = XCUIApplication.launched()
        app.breakingTab.tap()

        let row = moverRow(in: app)
        assertAppears(row, timeout: UIWait.firstLoad, "Movers should load")
        row.tap()

        assertAppears(app.backButton, timeout: UIWait.load,
                      "Tapping a mover should push its detail")
        attachScreenshot(of: app, named: "Breaking — mover detail")

        app.goBack()
        assertAppears(moverRow(in: app), timeout: UIWait.ui,
                      "Back should return to the movers list")
    }
}
