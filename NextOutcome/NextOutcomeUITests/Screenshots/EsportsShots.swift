//
//  EsportsShots.swift
//  NextOutcomeUITests
//
//  Esports hub and a match detail.
//

import XCTest

final class EsportsShots: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Launches straight into the Esports hub.
    private func esportsHub() -> XCUIApplication {
        let app = launchForScreenshots(preselecting: "esports", tagID: EsportsTag.id)
        settle(app, timeout: UIWait.firstLoad)
        return app
    }

    func test_esportsHub() {
        let app = esportsHub()
        capture("esports_hub", of: app)
    }

    func test_esportsMatchDetail() throws {
        let app = esportsHub()

        // The brief's `buttons CONTAINS "vs"` predicate for the match row does not exist
        // anywhere in this app's card views — confirmed against `EsportsMatchCard.swift` and
        // `EsportsHeroCard.swift`, neither of which composes "vs" text into a button label
        // (the "Team A vs Team B" string only ever appears inside a plain, non-interactive
        // `Text`). Both card kinds wrap their whole body — including a "$4M Vol" caption — in
        // a single `NavigationLink`, exactly the pattern `SportsShots`/`CryptoShots` already
        // use and `EsportsUITests.testEsportsMatchDetailOpensFromTheGamesList` already proves
        // against this same screen: tap the "Vol" caption via `anyVolumeLabel` to activate the
        // link without landing on some other tappable sub-element.
        //
        // Esports genuinely carries far fewer live matches than Sports at any given moment
        // (both `heroMatches` and `visibleMatches` in `EsportsHubViewModel` can be empty on a
        // quiet day) — a legitimate live-data gap, not a regression, so this uses
        // `requireMarket` rather than an assertion.
        try requireMarket(app.anyVolumeLabel, named: "esports_match_detail")
        app.anyVolumeLabel.tap()
        settle(app)

        // Per the task brief: assert this actually landed on the match detail screen rather
        // than trusting the tap. `EsportsMatchDetailView` renders a map-by-map scoreboard
        // (`EsportsScoreboardView`, identified `esports.scoreboard` — see
        // `EsportsMatchDetailView.swift` line 57 and `EsportsUITests.scoreboard`) that no
        // other screen in the app renders, including the Esports hub itself. Every card in
        // this hub comes from `heroMatches`/`visibleMatches` (matches only, never futures —
        // see `EsportsHubView.swift`), so a tap here landing anywhere but the match detail
        // screen is a real regression worth failing on, not a live-data state to skip.
        let scoreboard = app.otherElements["esports.scoreboard"]
        XCTAssertTrue(scoreboard.waitForExistence(timeout: UIWait.load),
                      "Tap did not open EsportsMatchDetailView — its map-by-map scoreboard "
                      + "never appeared. Might still be on the hub.")
        capture("esports_match_detail", of: app)
    }
}
