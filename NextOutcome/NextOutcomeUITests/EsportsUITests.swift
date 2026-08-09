//
//  EsportsUITests.swift
//  NextOutcome
//
//  Created by Sok Pich on 19/07/2026.
//
//  TC-090…TC-093: the Esports hub — deep-linked via
//  `-preselectCategory esports 64`. Covers the server-driven game-tile
//  row, the inline "Esports | Leaderboard" mode toggle, and the
//  `-forceTwitchChannel` stream-hero override.
//

import XCTest

final class EsportsUITests: XCTestCase {

    /// Polymarket's `esports` tag id.
    ///
    /// Not `100639` — that is the broader `games` tag (10k+ events against esports' ~750),
    /// which these tests used until 2026-08-09. They passed because Games is a superset, so
    /// the mistake was invisible.
    private let esportsTagID = "64"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// TC-090: the hub loads with game tiles and match cards.
    @MainActor
    func testEsportsHubLoadsWithGameTiles() throws {
        let app = XCUIApplication.launched(preselecting: "esports", tagID: esportsTagID)

        // Mode toggle chrome.
        assertAppears(app.esportsModeButton, timeout: UIWait.firstLoad,
                      "Expected the Esports mode button")
        XCTAssertTrue(app.leaderboardModeButton.exists,
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

    /// TC-093: the tile row is the server's game catalogue, not a hardcoded three.
    ///
    /// The row used to be a three-case enum (CS2 / LoL / Dota 2) while polymarket.com showed
    /// twelve games; it now comes from Gamma `/sports`. Scrolling the row past those three
    /// and finding a fourth game is the check that the catalogue is really driving it.
    @MainActor
    func testGameTileRowComesFromTheCatalogue() throws {
        let app = XCUIApplication.launched(preselecting: "esports", tagID: esportsTagID)
        assertAppears(app.esportsModeButton, timeout: UIWait.firstLoad, "Hub should load")
        // The tiles only exist once the events *and* the catalogue have landed — the mode
        // toggle above is chrome and shows during loading, so waiting on it proves nothing.
        assertAppears(app.anyVolumeLabel, timeout: UIWait.firstLoad, "Hub should finish loading")

        let legacyGames = ["CS2", "LoL", "Dota 2"]
        let tiles = app.buttons.matching(NSPredicate(format: "label != %@ AND label != %@",
                                                     "Esports", "Leaderboard"))

        var seen: Set<String> = []
        for _ in 0..<8 {
            for index in 0..<tiles.count {
                let label = tiles.element(boundBy: index).label
                if let game = legacyGames.first(where: { label.hasPrefix($0) }) {
                    seen.insert(game)
                } else if label.contains("live") {
                    seen.insert(label)
                }
            }
            if seen.count > legacyGames.count { break }
            // Swipe within the tile row, not the page: aim at the row's own vertical band.
            let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "CS2")).firstMatch
            if row.exists { row.swipeLeft() } else { app.swipeLeft() }
        }

        XCTAssertGreaterThan(
            seen.count, legacyGames.count,
            "The tile row should carry more games than the retired CS2/LoL/Dota 2 enum. Saw: \(seen.sorted())"
        )
        attachScreenshot(of: app, named: "Esports — game tile row")
    }

    /// TC-091: the inline Esports ⇄ Leaderboard toggle swaps content in place.
    @MainActor
    func testEsportsLeaderboardToggle() throws {
        let app = XCUIApplication.launched(preselecting: "esports", tagID: esportsTagID)

        let leaderboard = app.leaderboardModeButton
        assertAppears(leaderboard, timeout: UIWait.firstLoad, "Toggle should exist")
        leaderboard.tap()

        XCTAssertFalse(app.backButton.exists, "Mode toggle swaps in place — no push")
        attachScreenshot(of: app, named: "Esports — Leaderboard mode")

        app.esportsModeButton.tap()
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

        assertAppears(app.esportsModeButton, timeout: UIWait.firstLoad,
                      "Hub should load with the forced channel")
        // The Twitch embed lives in a WKWebView inside the hero card.
        assertAppears(app.webViews.firstMatch, timeout: UIWait.load,
                      "Expected the stream hero's Twitch embed web view")
        attachScreenshot(of: app, named: "Esports — forced Twitch hero")
    }
}

private extension XCUIApplication {
    /// The hub's inline mode buttons, addressed by identifier rather than label: the home
    /// rail also carries an "Esports" chip, so `buttons["Esports"]` matches two elements and
    /// any tap on it fails as ambiguous.
    var esportsModeButton: XCUIElement { buttons["esports.mode.esports"] }
    var leaderboardModeButton: XCUIElement { buttons["esports.mode.leaderboard"] }
}
