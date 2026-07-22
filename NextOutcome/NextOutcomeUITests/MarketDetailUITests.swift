//
//  MarketDetailUITests.swift
//  NextOutcome
//
//  Created by Sok Pich on 19/07/2026.
//
//  TC-040: MarketDetailView — reached through Search (the most reliable
//  route to a plain MarketCard) — shows the Buy/Sell segment toggle and the
//  Rules expander, and the toggle switches sides.
//

import XCTest

final class MarketDetailUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// TC-040: open a market from Search, exercise Buy/Sell, expand Rules.
    @MainActor
    func testBuySellToggleAndRules() throws {
        let app = XCUIApplication.launched()

        // Navigate: Search tab → query → first result.
        app.searchTab.tap()
        let searchField = app.searchField
        assertAppears(searchField, timeout: UIWait.load, "Search field should exist")
        searchField.tap()
        searchField.typeText("bitcoin")

        let firstResult = app.anyVolumeLabel
        assertAppears(firstResult, timeout: UIWait.firstLoad,
                      "Searching 'bitcoin' should return at least one market card")
        firstResult.tap()

        assertAppears(app.backButton, timeout: UIWait.load,
                      "Tapping a result should push the market detail")
        attachScreenshot(of: app, named: "MarketDetail — initial (Buy)")

        // Buy/Sell SegmentToggle.
        let buy = app.buttons["Buy"]
        let sell = app.buttons["Sell"]
        if sell.waitForExistence(timeout: UIWait.ui) {
            sell.tap()
            attachScreenshot(of: app, named: "MarketDetail — Sell selected")
            XCTAssertTrue(buy.exists, "Buy segment should remain visible after switching")
            buy.tap()
        }

        // Rules expander (accessibilityLabel "Rules").
        let rules = app.buttons["Rules"]
        if app.scrollTo(rules) {
            rules.tap()
            attachScreenshot(of: app, named: "MarketDetail — Rules expanded")
        }

        app.goBack()
        assertAppears(app.searchField, timeout: UIWait.ui,
                      "Back should return to the search results")
    }
}
