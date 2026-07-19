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
}
