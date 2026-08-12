//
//  TradeGateUITests.swift
//  NextOutcome
//
//  End-to-end cover for the geoblock gate. The gate lives inside TradeSheet rather than
//  at its six presentation sites, so these tests are what prove a real tap on a real
//  market is actually stopped — the unit tests only prove the policy and the copy.
//
//  Driven by the DEBUG-only `-simulateGeoblock` launch argument, so they need no VPN and
//  don't depend on where CI happens to run.
//

import XCTest

final class TradeGateUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Launches with a forced geoblock status and opens the trade sheet.
    ///
    /// Routes through Search → first result → market detail, the same path
    /// `MarketDetailUITests` uses: it's the most reliable way to reach a plain binary
    /// market. The feed's own Yes/No are `NavigationLink`s to detail, not sheet triggers.
    ///
    /// The trade row is matched on the cent sign its price carries, not on "Yes": a
    /// binary market's outcome titles are whatever the API says (Up/Down, team names),
    /// so the price is the only stable handle. It also sits below the fold, hence the
    /// scroll.
    @MainActor
    private func launchAndOpenTradeSheet(geoblock: String,
                                         extraArguments: [String] = []) throws -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-simulateGeoblock", geoblock]
        app.launchArguments += extraArguments
        app.launch()

        app.searchTab.tap()
        let searchField = app.searchField
        assertAppears(searchField, timeout: UIWait.load, "Search field should exist")
        searchField.tap()
        searchField.typeText("bitcoin")

        let firstResult = app.anyVolumeLabel
        assertAppears(firstResult, timeout: UIWait.firstLoad, "Search returned no markets")
        firstResult.tap()
        assertAppears(app.backButton, timeout: UIWait.load, "Market detail never pushed")

        let priceButton = app.buttons
            .matching(NSPredicate(format: "label CONTAINS %@", "¢")).firstMatch
        guard priceButton.waitForExistence(timeout: UIWait.load) else {
            throw XCTSkip("No binary market in today's search results")
        }
        app.scrollTo(priceButton)
        priceButton.tap()
        return app
    }

    /// The confirm button, matched by prefix — its label carries the outcome name.
    private func confirmButton(_ app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Trade")).firstMatch
    }

    @MainActor
    func test_blockedRegion_cannotReachTheConfirmButton() throws {
        let app = try launchAndOpenTradeSheet(geoblock: "blocked")

        assertAppears(app.staticTexts["Trading unavailable"], timeout: UIWait.ui,
                      "blocked region still got the trade sheet")
        // The two things that must be unreachable: the pad and the confirm button.
        XCTAssertFalse(confirmButton(app).exists, "confirm button reachable while blocked")
        XCTAssertFalse(app.buttons["+$5"].exists, "amount pad reachable while blocked")
        attachScreenshot(of: app, named: "TradeGate — blocked")
    }

    @MainActor
    func test_closeOnlyRegion_getsItsOwnWording() throws {
        let app = try launchAndOpenTradeSheet(geoblock: "closeOnly")

        assertAppears(app.staticTexts["Closing positions only"], timeout: UIWait.ui,
                      "close-only region did not get the close-only gate")
        // Close-only users can still exit positions — the copy must not claim otherwise.
        XCTAssertFalse(app.staticTexts["Trading unavailable"].exists,
                       "close-only region told trading is unavailable")
        XCTAssertFalse(confirmButton(app).exists, "confirm button reachable while close-only")
        attachScreenshot(of: app, named: "TradeGate — close only")
    }

    @MainActor
    func test_allowedRegion_getsTheNormalSheet() throws {
        let app = try launchAndOpenTradeSheet(geoblock: "allowed")

        assertAppears(confirmButton(app), timeout: UIWait.ui, "allowed region lost the trade sheet")
        XCTAssertFalse(app.staticTexts["Trading unavailable"].exists, "allowed region was gated")
    }

    /// The escape hatch that keeps the sheet demoable from a blocked region.
    @MainActor
    func test_debugOverride_reopensTheSheetWhileBlocked() throws {
        let app = try launchAndOpenTradeSheet(geoblock: "blocked",
                                              extraArguments: ["-allowTradingInBlockedRegion"])

        assertAppears(confirmButton(app), timeout: UIWait.ui,
                      "override did not restore the trade sheet")
        XCTAssertFalse(app.staticTexts["Trading unavailable"].exists, "override left the gate up")
    }
}
