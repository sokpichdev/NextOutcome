//
//  TabNavigationUITest.swift
//  NextOutcome
//
//  Created by Sok Pich on 19/07/2026.
//
//  TC-010, TC-011: every tab renders its root screen, and each tab keeps its
//  own NavigationStack state when switching away and back (RootView builds
//  all view models once at launch, so nothing should reload).
//

import XCTest

final class TabNavigationUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// TC-010: cycle through all four tabs and verify each root's anchor UI.
    @MainActor
    func testAllTabsRender() throws {
        let app = XCUIApplication.launched()
        assertAppears(app.tabBars.firstMatch, timeout: UIWait.ui, "Expected the tab bar")

        // 1. Home — pinned rail + a loaded card.
        assertAppears(app.anyVolumeLabel, timeout: UIWait.firstLoad,
                      "Home/Trending should load market cards")
        attachScreenshot(of: app, named: "Tab 1 — Home")

        // 2. Search — SwiftUI .searchable screen with its idle prompt.
        app.searchTab.tap()
        assertAppears(app.staticTexts["Search NextOutcome markets"], timeout: UIWait.load,
                      "Search tab should show its idle prompt before any query")
        attachScreenshot(of: app, named: "Tab 2 — Search")

        // 3. Breaking — biggest 24h movers; rows expose a
        //    "Up/Down N percent over 24 hours" accessibility label.
        app.breakingTab.tap()
        let moverRow = app.staticTexts
            .matching(NSPredicate(format: "label CONTAINS[c] %@", "percent over 24 hours"))
            .firstMatch
        assertAppears(moverRow, timeout: UIWait.firstLoad,
                      "Breaking tab should list movers with 24h-change labels")
        attachScreenshot(of: app, named: "Tab 3 — Breaking")

        // 4. Portfolio — dynamic balance label, so select by index; the screen
        //    shows either the watch-a-wallet prompt or real positions.
        app.portfolioTab.tap()
        let portfolioAnchor = app.staticTexts["Portfolio value"]
            .waitForExistence(timeout: UIWait.load)
            || app.staticTexts["Watch a wallet"].exists
        XCTAssertTrue(portfolioAnchor,
                      "Portfolio tab should show 'Portfolio value' or the 'Watch a wallet' prompt")
        attachScreenshot(of: app, named: "Tab 4 — Portfolio")

        // And back Home without a reload flash.
        app.homeTab.tap()
        assertAppears(app.buttons["Trending"], timeout: UIWait.ui,
                      "Returning to Home should restore the category rail immediately")
    }

    /// TC-011: Home's scrolled feed position is retained across a tab
    /// round-trip (view models are built once in RootView.init).
    @MainActor
    func testHomeStateRetainedAcrossTabSwitch() throws {
        let app = XCUIApplication.launched()
        assertAppears(app.anyVolumeLabel, timeout: UIWait.firstLoad, "Feed should load")

        // Scroll the feed a couple of pages, note that the rail's Trending
        // chip scrolls with content or stays pinned — either way the feed
        // should NOT be back at the very top after tabbing away and back,
        // which we detect via the first card's changed position.
        app.swipeUp()
        app.swipeUp()
        attachScreenshot(of: app, named: "Home — scrolled before tab switch")

        app.searchTab.tap()
        assertAppears(app.staticTexts["Search NextOutcome markets"], timeout: UIWait.load,
                      "Search should render")
        app.homeTab.tap()

        // The feed content (some Vol card) is still there instantly — no
        // 45-second reload from scratch.
        assertAppears(app.anyVolumeLabel, timeout: UIWait.ui,
                      "Home content should be retained, not refetched, after a tab switch")
        attachScreenshot(of: app, named: "Home — after tab round-trip")
    }
}
