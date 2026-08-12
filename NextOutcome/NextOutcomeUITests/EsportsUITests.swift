//
//  EsportsUITests.swift
//  NextOutcome
//
//  Created by Sok Pich on 19/07/2026.
//
//  TC-090…TC-096: the Esports hub and match detail screen — deep-linked
//  via `-preselectCategory esports 64`. Covers the server-driven game-tile
//  row, the inline "Esports | Leaderboard" mode toggle, the
//  `-forceTwitchChannel` stream-hero override, and the match detail
//  screen's scoreboard, market sections and Livestream tab.
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

    /// TC-094: YouTube-hosted broadcasts get a player, not artwork.
    ///
    /// Mobile Legends points every match at YouTube, and the keyless liveness probe can't
    /// read YouTube (bot check on `watch?v=`, 404 on `/@handle/streams`), so those heroes
    /// showed artwork while polymarket.com played the stream. Swipes the hero carousel
    /// looking for any YouTube player.
    ///
    /// Skips when no YouTube-hosted match happens to be live — the assertion needs live
    /// data, and a red test that only means "nothing is on air" is worse than none.
    @MainActor
    func testYouTubeBroadcastsGetAPlayer() throws {
        let app = XCUIApplication.launched(preselecting: "esports", tagID: esportsTagID)
        assertAppears(app.esportsModeButton, timeout: UIWait.firstLoad, "Hub should load")
        assertAppears(app.anyVolumeLabel, timeout: UIWait.firstLoad, "Hub should finish loading")

        func matching(_ prefix: String) -> XCUIElementQuery {
            app.descendants(matching: .any)
                .matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix))
        }

        // The hero media areas are identified `stream-<platform>-<broadcast>` (or
        // `stream-artwork`), so their presence says exactly which branch rendered. Cards
        // outside the viewport are still in the tree, which is what makes this assertable
        // without hunting through the carousel.
        XCTAssertGreaterThan(matching("stream-").count, 0,
                             "No hero media area was addressable — EsportsStreamView's "
                             + "accessibility identifier is not reaching the tree")

        // `allElementsBoundByIndex`, not `.firstMatch`: a `.any` descendants query resolves
        // `firstMatch` unreliably here — it reported no match while the full list held one.
        func heroIdentifiers() -> [String] {
            matching("stream-").allElementsBoundByIndex.map(\.identifier)
        }
        func youTubePlayerIsPresent() -> Bool {
            heroIdentifiers().contains { $0.hasPrefix("stream-youtube-") }
        }

        // The carousel is lazy, so only nearby cards are in the tree — swipe to widen it.
        var swipes = 0
        while !youTubePlayerIsPresent() && swipes < 12 {
            guard let visibleHero = matching("stream-").allElementsBoundByIndex
                .first(where: \.isHittable) else { break }
            visibleHero.swipeLeft()
            swipes += 1
        }

        try XCTSkipUnless(
            youTubePlayerIsPresent(),
            "No YouTube-hosted match is live right now — nothing to assert against. "
            + "Heroes seen: \(heroIdentifiers())")
        attachScreenshot(of: app, named: "Esports — YouTube stream hero")
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
    /// so the embed WebView renders. The visual "is video actually playing"
    /// check stays manual (TC-130).
    ///
    /// The hero embeds only confirmed-live broadcasts, so this asserts something about the
    /// outside world as much as about the app: when the channel is off air there is
    /// correctly no player, and failing then would just mean "nobody is streaming". The
    /// precondition check separates the two, so a real regression still fails.
    @MainActor
    func testForcedTwitchChannelHero() async throws {
        let channel = "esl_csgo"
        switch await BroadcastPrecondition.twitchStatus(channel: channel) {
        case .live:
            break
        case .offAir:
            throw XCTSkip("twitch.tv/\(channel) is off air — the hero embeds only live "
                          + "broadcasts, so there is nothing to assert")
        case .unknown:
            throw XCTSkip("Couldn't determine whether twitch.tv/\(channel) is live "
                          + "(network or page-shape change) — not treating that as off air")
        }

        let app = XCUIApplication.launched(
            preselecting: "esports", tagID: esportsTagID,
            extraArguments: ["-forceTwitchChannel", channel])

        assertAppears(app.esportsModeButton, timeout: UIWait.firstLoad,
                      "Hub should load with the forced channel")
        // The Twitch embed lives in a WKWebView inside the hero card.
        assertAppears(app.webViews.firstMatch, timeout: UIWait.load,
                      "Expected the stream hero's Twitch embed web view")
        attachScreenshot(of: app, named: "Esports — forced Twitch hero")
    }
    /// TC-095: tapping a match opens the purpose-built detail screen.
    ///
    /// The section assertion is the point of this test. Esports markets name their outcomes
    /// after the teams, and the screen this replaced classified none of them — so every
    /// market landed in one "Other" pile with no prices. Finding a real section header is
    /// what catches that regression coming back.
    @MainActor
    func testEsportsMatchDetailOpensFromTheGamesList() throws {
        let app = XCUIApplication.launched(preselecting: "esports", tagID: esportsTagID)

        assertAppears(app.esportsModeButton, timeout: UIWait.firstLoad, "Hub should load")
        guard app.anyVolumeLabel.waitForExistence(timeout: UIWait.firstLoad) else {
            throw XCTSkip("No esports matches are listed right now — nothing to open")
        }

        app.anyVolumeLabel.tap()
        assertAppears(app.backButton, timeout: UIWait.load, "Tapping a match should push a screen")

        assertAppears(app.scoreboard, timeout: UIWait.load,
                      "The match screen should show its map-by-map scoreboard")
        XCTAssertTrue(app.marketSegment.exists, "Expected the Market/Livestream toggle")

        // Any real section beats the "everything is Other" failure mode. Which sections a
        // given match carries depends on its game, so accept any of the esports set.
        let sectionTitles = ["Moneyline", "Map Winners", "Totals", "Map Rounds"]
        let hasRealSection = sectionTitles.contains { title in
            app.staticTexts[title].waitForExistence(timeout: UIWait.load)
                || app.scrollTo(app.staticTexts[title], maxSwipes: 3)
        }
        XCTAssertTrue(hasRealSection,
                      "Expected a classified market section, one of \(sectionTitles) — "
                      + "their absence means the markets fell back into \"Other\"")
        attachScreenshot(of: app, named: "Esports — match detail")
    }

    /// TC-096: the Livestream tab either plays the broadcast or offers to open it.
    ///
    /// Like TC-092 this asserts partly about the outside world: only a live match has a
    /// broadcast at all. What must always hold is that the tab shows *something* honest —
    /// a player, or artwork plus a way out to the real stream — never a dead frame.
    @MainActor
    func testLivestreamSegmentShowsAPlayerOrAnOpenBroadcastLink() throws {
        let app = XCUIApplication.launched(preselecting: "esports", tagID: esportsTagID)

        assertAppears(app.esportsModeButton, timeout: UIWait.firstLoad, "Hub should load")
        guard app.anyVolumeLabel.waitForExistence(timeout: UIWait.firstLoad) else {
            throw XCTSkip("No esports matches are listed right now — nothing to open")
        }
        app.anyVolumeLabel.tap()
        assertAppears(app.backButton, timeout: UIWait.load, "Tapping a match should push a screen")

        let livestream = app.buttons["Livestream"]
        guard livestream.waitForExistence(timeout: UIWait.load) else {
            throw XCTSkip("The Livestream segment didn't appear — no broadcast tab to check")
        }
        livestream.tap()

        // One of the three `stream-*` identifiers always renders: a Twitch or YouTube
        // player, or the artwork placeholder.
        let artwork = app.otherElements["stream-artwork"]
        let player = app.webViews.firstMatch
        let showedSomething = artwork.waitForExistence(timeout: UIWait.load) || player.exists
        XCTAssertTrue(showedSomething, "The Livestream tab should show a player or artwork")

        if player.exists {
            // A player only renders when the event listed a broadcast URL, so the way out to
            // the full-size stream must be offered — the inline player is view-only, and this
            // is the only route to watching properly.
            XCTAssertTrue(app.openBroadcastLink.exists,
                          "A playing stream should still offer a link to the full broadcast")
        } else if artwork.exists {
            // No embeddable broadcast: the screen must still offer the real one when the
            // event lists a URL (Kick, which we can't embed, is common on esports events).
            XCTAssertTrue(
                app.openBroadcastLink.exists
                    || app.staticTexts["No broadcast is listed for this match."].exists
                    || app.staticTexts["The broadcast starts when the match goes live."].exists
                    || app.staticTexts["This match has finished."].exists,
                "With no player, expect an Open broadcast link or an explicit reason there isn't one")
        }
        attachScreenshot(of: app, named: "Esports — match detail livestream")
    }
}

private extension XCUIApplication {
    /// The hub's inline mode buttons, addressed by identifier rather than label: the home
    /// rail also carries an "Esports" chip, so `buttons["Esports"]` matches two elements and
    /// any tap on it fails as ambiguous.
    var esportsModeButton: XCUIElement { buttons["esports.mode.esports"] }
    var leaderboardModeButton: XCUIElement { buttons["esports.mode.leaderboard"] }
    /// The match detail screen's map-by-map scoreboard.
    var scoreboard: XCUIElement { otherElements["esports.scoreboard"] }
    /// The match detail screen's Market/Livestream toggle.
    var marketSegment: XCUIElement { otherElements["esports.detail.segment"] }
    /// The Livestream tab's link out to a broadcast we can't embed.
    var openBroadcastLink: XCUIElement { buttons["esports.detail.openBroadcast"] }
}
