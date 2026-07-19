//
//  PortfolioUITests.swift
//  NextOutcome
//
//  Created by Sok Pich on 19/07/2026.
//
//  TC-110: the Portfolio tab (watch-only). Depending on whether a wallet is
//  already tracked on this simulator, the screen shows either the
//  "Watch a wallet" prompt or the positions dashboard — both are valid.
//

import XCTest

final class PortfolioUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// TC-110: the tab renders one of its two legitimate states, scrolls,
    /// and survives pull-to-refresh.
    @MainActor
    func testPortfolioTabRenders() throws {
        let app = XCUIApplication.launched()
        app.portfolioTab.tap()

        let dashboard = app.staticTexts["Portfolio value"]
        let prompt = app.staticTexts["Watch a wallet"]
        let rendered = dashboard.waitForExistence(timeout: UIWait.firstLoad) || prompt.exists
        XCTAssertTrue(rendered,
                      "Portfolio should show the dashboard or the watch-a-wallet prompt")
        attachScreenshot(of: app, named: "Portfolio — initial state")

        if dashboard.exists {
            // Dashboard state: open/closed positions sections exist somewhere
            // down the scroll.
            let openPositions = app.staticTexts["Open positions"]
            app.scrollTo(openPositions)
            XCTAssertTrue(openPositions.exists,
                          "A tracked wallet should list its open positions section")
            app.scrollTo(app.staticTexts["Closed positions"], maxSwipes: 4)
            attachScreenshot(of: app, named: "Portfolio — positions")

            for _ in 1...4 { app.swipeDown() }
            app.pullToRefresh()
            assertAppears(dashboard, timeout: UIWait.load,
                          "Dashboard should survive a refresh")
        } else {
            // Empty state: the read-only tracking explainer and CTA exist.
            XCTAssertTrue(app.buttons["Track wallet"].exists
                            || app.staticTexts["Track wallet"].exists,
                          "The empty state should offer the Track wallet action")
        }
    }
}
