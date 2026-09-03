//
//  ShellShots.swift
//  NextOutcomeUITests
//
//  Tab-bar level screens: Portfolio, Search, and the dark-theme sample.
//

import XCTest

final class ShellShots: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func test_portfolio() {
        let app = launchForScreenshots()
        settle(app, timeout: UIWait.firstLoad)
        app.portfolioTab.tap()
        settle(app)
        capture("portfolio", of: app)
    }

    func test_search() {
        let app = launchForScreenshots()
        settle(app, timeout: UIWait.firstLoad)
        app.searchTab.tap()
        XCTAssertTrue(app.searchField.waitForHittable(timeout: UIWait.ui),
                      "Search field never became hittable")
        app.searchField.tap()
        app.searchField.typeText("world cup")
        settle(app)
        capture("search", of: app)
    }

    func test_themeDark() {
        let app = launchForScreenshots()
        settle(app, timeout: UIWait.firstLoad)
        capture("theme_dark", of: app)
    }
}
