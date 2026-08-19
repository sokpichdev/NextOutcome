//
//  TabBarVisibilityUITests.swift
//  NextOutcome
//
//  TC-090…TC-091: the bottom tab bar belongs to the main screens. Pushing a
//  detail screen hands its space back to the content; popping restores it.
//

import XCTest

final class TabBarVisibilityUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// TC-090: a detail screen pushed from the Home feed hides the tab bar, and
    /// Back brings it straight back.
    @MainActor
    func testEventDetailHidesTabBarAndBackRestoresIt() throws {
        let app = XCUIApplication.launched()
        let firstCard = app.anyVolumeLabel
        assertAppears(firstCard, timeout: UIWait.firstLoad, "Feed should load")

        XCTAssertTrue(app.homeTab.exists, "The tab bar belongs on the Home feed")

        firstCard.tap()
        assertAppears(app.backButton, timeout: UIWait.load,
                      "Tapping a card should push a detail screen")

        XCTAssertTrue(waitForTabBar(app, toExist: false),
                      "A pushed detail screen must hide the tab bar")
        attachScreenshot(of: app, named: "EventDetail — no tab bar")

        // The feed's cards, not the rail's "Trending" chip: the chip assertion is what
        // TC-023 uses and it fails on this branch's parent too, so relying on it here
        // would report a pre-existing navigation flake as a tab-bar regression.
        //
        // And the Back button is waited on rather than probed: `goBack()` falls through to
        // an edge swipe the moment it isn't there yet, and a swipe landing on the detail
        // screen's chart scrolls it instead of popping.
        XCTAssertTrue(app.backButton.waitForHittable(timeout: UIWait.ui),
                      "The detail screen's Back button should become tappable")
        app.backButton.tap()
        assertAppears(app.anyVolumeLabel, timeout: UIWait.load,
                      "Back should land on the Home feed")
        XCTAssertTrue(waitForTabBar(app, toExist: true),
                      "Popping back to a main screen must restore the tab bar")
        attachScreenshot(of: app, named: "Home feed — tab bar restored")
    }

    /// TC-091: the crypto live screen — pushed from the Crypto hub — hides it too,
    /// so the chart and bet controls own the bottom of the screen.
    @MainActor
    func testCryptoLiveScreenHidesTabBar() throws {
        let app = XCUIApplication.launched(preselecting: "crypto", tagID: "21")

        let card = app.staticTexts
            .matching(NSPredicate(format: "label CONTAINS[c] %@", "Up or Down"))
            .firstMatch
        assertAppears(card, timeout: UIWait.firstLoad,
                      "Crypto hub should pin the live Up/Down card")
        XCTAssertTrue(app.homeTab.exists, "The tab bar belongs on the Crypto hub")

        card.tap()
        assertAppears(app.buttons["Candles"], timeout: UIWait.load,
                      "Tapping the card should push the live screen")

        XCTAssertTrue(waitForTabBar(app, toExist: false),
                      "The live screen must hide the tab bar")
        attachScreenshot(of: app, named: "BTC live — no tab bar")
    }

    /// Waits for the tab bar to appear or disappear, since the bar animates in and
    /// out with the push rather than flipping on the same frame as the transition.
    /// - Parameters:
    ///   - app: The application under test.
    ///   - shouldExist: The state to wait for.
    /// - Returns: Whether the bar reached that state within the UI timeout.
    private func waitForTabBar(_ app: XCUIApplication, toExist shouldExist: Bool) -> Bool {
        let deadline = Date().addingTimeInterval(UIWait.ui)
        while Date() < deadline {
            if app.tabBars.firstMatch.exists == shouldExist { return true }
            Thread.sleep(forTimeInterval: 0.25)
        }
        return app.tabBars.firstMatch.exists == shouldExist
    }
}
