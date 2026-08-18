//
//  CryptoUITests.swift
//  NextOutcome
//
//  Created by Sok Pich on 19/07/2026.
//
//  TC-080: the Crypto hub, deep-linked via `-preselectCategory crypto 21`
//  (DEBUG builds only). Verifies the timeframe chips (5 Min / 15 Min /
//  1 Hour / Daily …) and that market content loads.
//

import XCTest

final class CryptoUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// TC-080: the hub renders its timeframe chips and cards, and a chip tap
    /// filters in place.
    @MainActor
    func testCryptoHubLoads() throws {
        // Tag 21 is Polymarket's crypto tag; the slug drives which hub view
        // RootView swaps in (id == "crypto" → CryptoHubView).
        let app = XCUIApplication.launched(preselecting: "crypto", tagID: "21")

        // Timeframe filter chips are the hub's stable chrome.
        let hourly = app.buttons["1 Hour"]
        assertAppears(hourly, timeout: UIWait.firstLoad,
                      "Crypto hub should show its timeframe chips")
        attachScreenshot(of: app, named: "Crypto hub — loaded")

        hourly.tap()
        XCTAssertFalse(app.backButton.exists,
                       "Timeframe chips filter in place — no push")
        // Cards render either the "24hr Volume" caption or a compact "Vol" label.
        let volumeInfo = app.staticTexts
            .matching(NSPredicate(format: "label CONTAINS[c] %@", "Vol"))
            .firstMatch
        assertAppears(volumeInfo, timeout: UIWait.load,
                      "Filtered crypto content should render volume info")
        attachScreenshot(of: app, named: "Crypto hub — 1 Hour filter")

        app.pullToRefresh()
        assertAppears(app.buttons["1 Hour"], timeout: UIWait.load,
                      "Hub chrome should survive a refresh")
    }

    /// TC-081: the BTC live screen's Candles mode draws real multi-hour history from the
    /// chainlink-candles feed (not just the current window's lone forming candle), and
    /// dragging right scrolls back through older candles, paging more in as needed.
    /// Chart marks aren't exposed to accessibility, so the render itself is verified via
    /// the attached screenshots; the assertions cover the mode switch surviving both the
    /// data load and the scroll.
    @MainActor
    func testBTCLiveCandleChartShowsHistoryAndScrollsBack() throws {
        let app = XCUIApplication.launched(preselecting: "crypto", tagID: "21")

        let card = app.staticTexts
            .matching(NSPredicate(format: "label CONTAINS[c] %@", "Up or Down"))
            .firstMatch
        assertAppears(card, timeout: UIWait.firstLoad,
                      "Crypto hub should pin the live Up/Down card")
        card.tap()

        let candlesChip = app.buttons["Candles"]
        assertAppears(candlesChip, timeout: UIWait.load,
                      "Live screen should show its chart-mode chips")
        candlesChip.tap()
        // Let the candle-history page land before capturing.
        Thread.sleep(forTimeInterval: 4)
        attachScreenshot(of: app, named: "BTC live — candle history")

        // Drag the chart area to the right to scroll back into older candles.
        let window = app.windows.firstMatch
        let chartMiddle = window.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.33))
        let chartRight = window.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.33))
        chartMiddle.press(forDuration: 0.05, thenDragTo: chartRight)
        Thread.sleep(forTimeInterval: 2)
        attachScreenshot(of: app, named: "BTC live — candles scrolled back")

        XCTAssertTrue(candlesChip.exists,
                      "Candles mode must survive the history load and scroll-back")
    }

    /// TC-083: the bet controls are pinned to the bottom of the live screen, so a market
    /// with minutes to run can be traded without scrolling back up past the trades ticker.
    @MainActor
    func testBetControlsStayPinnedWhileScrolling() throws {
        let app = XCUIApplication.launched(preselecting: "crypto", tagID: "21")

        let card = app.staticTexts
            .matching(NSPredicate(format: "label CONTAINS[c] %@", "Up or Down"))
            .firstMatch
        assertAppears(card, timeout: UIWait.firstLoad,
                      "Crypto hub should pin the live Up/Down card")
        card.tap()

        // The side selectors carry an accessibility label of "Up, 24¢" / "Up, --".
        let upButton = app.buttons
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Up,"))
            .firstMatch
        assertAppears(upButton, timeout: UIWait.load,
                      "The live screen should show its Up selector")
        XCTAssertTrue(upButton.waitForHittable(timeout: UIWait.ui),
                      "The Up selector should be tappable on entry")

        // Frames, not visibility: this screen is short enough that a scrolling bet row can
        // still be on screen at the bottom of the content, so "is it visible" would pass
        // whether or not it is pinned. A pinned row's frame doesn't move; a scrolling one's
        // does, by exactly what the content scrolled.
        let betRowBefore = upButton.frame
        // Scrolled far enough, the title leaves the screen entirely, and a missing element
        // reports a zero frame — which is still "moved", so this reads either way.
        let header = app.staticTexts["BTC Up or Down 5m"]
        let headerBefore = header.exists ? header.frame.minY : 0

        for _ in 1...4 { app.swipeUp() }

        let headerAfter = header.exists ? header.frame.minY : 0
        XCTAssertNotEqual(headerBefore, headerAfter, accuracy: 1,
                          "Precondition: the screen's content must actually have scrolled")
        XCTAssertEqual(upButton.frame.minY, betRowBefore.minY, accuracy: 1,
                       "The bet controls must stay put while the content scrolls under them")
        attachScreenshot(of: app, named: "BTC live — bet bar pinned after scroll")
    }

    /// TC-082: once a window closes, "Next window →" must actually leave the closed
    /// screen and land back on the hub (regression: the pop used to be wired to the
    /// hub's own `dismiss`, which is a no-op at the stack root, so the button did
    /// nothing). Waits out the remainder of the live 5-minute window, so this test can
    /// take up to ~5.5 minutes — keep it out of any quick smoke run.
    @MainActor
    func testNextWindowButtonReturnsToHub() throws {
        let app = XCUIApplication.launched(preselecting: "crypto", tagID: "21")

        let card = app.staticTexts
            .matching(NSPredicate(format: "label CONTAINS[c] %@", "Up or Down"))
            .firstMatch
        assertAppears(card, timeout: UIWait.firstLoad,
                      "Crypto hub should pin the live Up/Down card")
        card.tap()

        // The screen stays put on the opened window; a 5-minute window always closes
        // within 5 minutes of entry, at which point the quick-bet row becomes the
        // next-window button.
        let nextWindow = app.buttons["Next window →"]
        assertAppears(nextWindow, timeout: 320,
                      "the opened 5-minute window should settle within 5 minutes")
        attachScreenshot(of: app, named: "BTC live — window closed")
        nextWindow.tap()

        // The chip's label carries the live market count ("1 Hour, 7"), so match on
        // the prefix rather than the exact string.
        let hourChip = app.buttons
            .matching(NSPredicate(format: "label BEGINSWITH %@", "1 Hour"))
            .firstMatch
        assertAppears(hourChip, timeout: UIWait.ui,
                      "Next window must pop back to the Crypto hub")
        attachScreenshot(of: app, named: "Hub after Next window")
    }
}
