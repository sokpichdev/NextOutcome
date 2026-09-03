//
//  HomeShots.swift
//  NextOutcomeUITests
//
//  Home feed: the default trending feed and the category rails reachable from it.
//

import XCTest

final class HomeShots: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func test_homeTrending() {
        let app = launchForScreenshots()
        settle(app, timeout: UIWait.firstLoad)
        capture("home_trending", of: app)
    }

    func test_homeTrendingWorldCupWinners() throws {
        let app = launchForScreenshots()
        settle(app, timeout: UIWait.firstLoad)
        // Plain "Winner" is too loose: it also matches unrelated cards like "2026 Men's US
        // Open Winner (Tennis)" that are already on screen, which would silently capture a
        // duplicate of home_trending instead of a World Cup card. Require both terms, and
        // skip (rather than mis-capture) when no such card is currently trending.
        let winners = app.staticTexts
            .matching(NSPredicate(format: "label CONTAINS[c] %@ AND label CONTAINS[c] %@",
                                   "World Cup", "Winner")).firstMatch
        app.scrollTo(winners, maxSwipes: 15)
        try requireMarket(winners, named: "home_trending_worldcup_winners")
        settle(app)
        capture("home_trending_worldcup_winners", of: app)
    }

    func test_homeBreaking() {
        let app = launchForScreenshots()
        settle(app, timeout: UIWait.firstLoad)
        app.breakingTab.tap()
        settle(app)
        capture("home_breaking", of: app)
    }

    func test_breakingMovers() {
        let app = launchForScreenshots()
        settle(app, timeout: UIWait.firstLoad)
        app.breakingTab.tap()
        settle(app)
        // The Breaking screen has no on-screen "Movers" text (that word only appears in
        // type/file names, not rendered UI) — matching it never succeeds. Anchor on a
        // ranked row deep enough in the list (past the hero banner and category pills,
        // which alone fill the first screen on this device) so the shot is visibly
        // distinct from home_breaking. `pageSize` for the movers query is 25, so ranks
        // 10-15 are reliably present.
        let deepMover = app.staticTexts
            .matching(NSPredicate(format: "label IN %@",
                                   ["10", "11", "12", "13", "14", "15"])).firstMatch
        app.scrollTo(deepMover)
        settle(app)
        capture("breaking_movers", of: app)
    }

    func test_homePolitics() {
        let app = launchForScreenshots(preselecting: "politics", tagID: PoliticsTag.id)
        settle(app, timeout: UIWait.firstLoad)
        capture("home_politics", of: app)
    }
}
