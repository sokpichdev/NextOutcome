//
//  HomeFeedUITests.swift
//  NextOutcome
//
//  Created by Sok Pich on 19/07/2026.
//
//  TC-020…TC-023: the Trending event feed — load, scroll, pull-to-refresh,
//  and the card → EventDetailView → back round trip including the
//  DetailToolbar accessibility buttons.
//

import XCTest

final class HomeFeedUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// TC-020: the Trending feed loads real event cards.
    @MainActor
    func testTrendingFeedLoads() throws {
        let app = XCUIApplication.launched()

        assertAppears(app.anyVolumeLabel, timeout: UIWait.firstLoad,
                      "Trending should load at least one event card")
        XCTAssertFalse(app.staticTexts["No results"].exists,
                       "Trending must not show the empty state on a healthy network")
        attachScreenshot(of: app, named: "Trending feed loaded")
    }

    /// TC-021: the feed scrolls and keeps presenting cards page after page.
    @MainActor
    func testFeedScrolls() throws {
        let app = XCUIApplication.launched()
        assertAppears(app.anyVolumeLabel, timeout: UIWait.firstLoad, "Feed should load")

        for page in 1...4 {
            app.swipeUp()
            assertAppears(app.anyVolumeLabel, timeout: UIWait.ui,
                          "Cards should still be present after scroll page \(page)")
        }
        attachScreenshot(of: app, named: "Trending — scrolled 4 pages")

        // And back to the top.
        for _ in 1...4 { app.swipeDown() }
        assertAppears(app.buttons["Trending"], timeout: UIWait.ui,
                      "The category rail should be visible again at the top")
    }

    /// TC-022: pull-to-refresh completes and the feed remains populated.
    @MainActor
    func testPullToRefresh() throws {
        let app = XCUIApplication.launched()
        assertAppears(app.anyVolumeLabel, timeout: UIWait.firstLoad, "Feed should load")

        app.pullToRefresh()

        // After the refresh settles the feed must still have cards and no
        // error/empty state.
        assertAppears(app.anyVolumeLabel, timeout: UIWait.load,
                      "Feed should be repopulated after pull-to-refresh")
        XCTAssertFalse(app.staticTexts["No results"].exists,
                       "Refresh must not leave the feed empty")
        attachScreenshot(of: app, named: "Trending — after pull-to-refresh")
    }

    /// TC-023: tapping a card pushes EventDetailView (sticky header, market
    /// sections, DetailToolbar), and Back returns to the feed.
    @MainActor
    func testOpenEventDetailAndBack() throws {
        let app = XCUIApplication.launched()
        let firstCard = app.anyVolumeLabel
        assertAppears(firstCard, timeout: UIWait.firstLoad, "Feed should load")

        firstCard.tap()

        // A push happened…
        assertAppears(app.backButton, timeout: UIWait.load,
                      "Tapping a card should push a detail screen")
        // …and the DetailToolbar's accessibility-labelled actions are there.
        for action in ["Bookmark", "Share link"] {
            XCTAssertTrue(app.buttons[action].waitForExistence(timeout: UIWait.ui),
                          "Expected the '\(action)' toolbar action on the detail screen")
        }
        attachScreenshot(of: app, named: "EventDetail — pushed from Trending")

        app.goBack()
        assertAppears(app.buttons["Trending"], timeout: UIWait.ui,
                      "Back should land on the Home feed with the rail visible")
    }
}
