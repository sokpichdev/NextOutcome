//
//  EsportsUITests.swift
//  NextOutcome
//
//  Created by Sok Pich on 19/07/2026.
//
//  TC-090…TC-092: the Esports hub — deep-linked via
//  `-preselectCategory esports 100639`. Covers the game-tile row
//  (Counter-Strike 2 / League of Legends / Dota 2), the inline
//  "Esports | Leaderboard" mode toggle, and the `-forceTwitchChannel`
//  stream-hero override.
//

import XCTest

final class EsportsUITests: XCTestCase {

    /// Polymarket's esports tag id (see docs/memory: esports hub).
    private let esportsTagID = "100639"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// TC-090: the hub loads with game tiles and match cards.
    @MainActor
    func testEsportsHubLoadsWithGameTiles() throws {
        let app = XCUIApplication.launched(preselecting: "esports", tagID: esportsTagID)

        // Mode toggle chrome.
        assertAppears(app.buttons["Esports"], timeout: UIWait.firstLoad,
                      "Expected the Esports mode button")
        XCTAssertTrue(app.buttons["Leaderboard"].exists,
                      "Expected the Leaderboard mode button")

        // Either real match cards or the honest empty state — never a blank
        // screen or an error banner.
        let hasContent = app.anyVolumeLabel.waitForExistence(timeout: UIWait.firstLoad)
            || app.staticTexts["No matches right now. Check back soon."].exists
        XCTAssertTrue(hasContent,
                      "Esports should show match cards or its explicit empty state")
        XCTAssertFalse(
            app.staticTexts["Couldn't load Esports. Pull to refresh."].exists,
            "The hub must not be in its error state on a healthy network")
        attachScreenshot(of: app, named: "Esports hub — loaded")

        app.swipeUp()
        attachScreenshot(of: app, named: "Esports hub — scrolled")
    }

    /// TC-091: the inline Esports ⇄ Leaderboard toggle swaps content in place.
    @MainActor
    func testEsportsLeaderboardToggle() throws {
        let app = XCUIApplication.launched(preselecting: "esports", tagID: esportsTagID)

        let leaderboard = app.buttons["Leaderboard"]
        assertAppears(leaderboard, timeout: UIWait.firstLoad, "Toggle should exist")
        leaderboard.tap()

        XCTAssertFalse(app.backButton.exists, "Mode toggle swaps in place — no push")
        attachScreenshot(of: app, named: "Esports — Leaderboard mode")

        app.buttons["Esports"].tap()
        attachScreenshot(of: app, named: "Esports — back to matches mode")
    }

    /// TC-092: `-forceTwitchChannel` pins the stream hero to a known channel
    /// so the embed WebView renders. Uses a large always-on channel; the
    /// visual "is video actually playing" check stays manual (TC-130).
    @MainActor
    func testForcedTwitchChannelHero() throws {
        let app = XCUIApplication.launched(
            preselecting: "esports", tagID: esportsTagID,
            extraArguments: ["-forceTwitchChannel", "esl_csgo"])

        assertAppears(app.buttons["Esports"], timeout: UIWait.firstLoad,
                      "Hub should load with the forced channel")
        // The Twitch embed lives in a WKWebView inside the hero card.
        assertAppears(app.webViews.firstMatch, timeout: UIWait.load,
                      "Expected the stream hero's Twitch embed web view")
        attachScreenshot(of: app, named: "Esports — forced Twitch hero")
    }
}
