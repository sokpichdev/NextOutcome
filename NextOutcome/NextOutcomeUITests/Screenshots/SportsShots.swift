//
//  SportsShots.swift
//  NextOutcomeUITests
//
//  Sports hub, its sub-tabs, and the World Cup surfaces.
//
//  Several shots here are tied to the 2026 FIFA World Cup, which has concluded by the time
//  this suite runs. Those use `requireMarket` (or an equivalent live-content check) so an
//  absent/empty screen skips with a named message rather than capturing an empty state or a
//  different market under the old filename.
//

import XCTest

final class SportsShots: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Launches straight into the Sports hub.
    private func sportsHub() -> XCUIApplication {
        let app = launchForScreenshots(preselecting: "sports", tagID: SportsTag.id)
        settle(app, timeout: UIWait.firstLoad)
        return app
    }

    /// Finds a chip in the Sports hub's `SportsNavBar` (Live / Futures mode toggles, or a
    /// dynamic per-sport chip like "MLB" / "World Cup").
    ///
    /// These chips compose an icon (or live dot) plus a name plus, for sport chips, an
    /// active-event count into one accessibility label (e.g. "MLB, 200") — never the bare
    /// title the v1 UI used. An exact `app.buttons["MLB"]` match never hits, so this matches
    /// by substring instead.
    /// - Parameters:
    ///   - text: The substring identifying the chip (e.g. "Live", "MLB", "World Cup").
    ///   - app: The application under test.
    /// - Returns: The chip element (not yet checked for existence/hittability).
    private func sportsChip(containing text: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", text)).firstMatch
    }

    /// Scrolls the Sports hub's chip row until `chip` sits fully within the screen.
    ///
    /// The row is a horizontal `ScrollView` holding one chip per sport with something open to
    /// trade, so a chip further down the catalogue (MLB, on a normal day, is not one of the
    /// first two) starts off-screen. Evaluating `.isHittable` on an off-screen element doesn't
    /// just return `false` here — the run that first wrote this test crashed on
    /// "Activation point invalid and no suggested hit points based on element frame" from
    /// exactly that check (`waitForHittable`, via `test_homeSportsMLB`/`test_teamProfile`).
    /// So this scrolls using `.frame` containment instead, which is safe to read off-screen,
    /// and only touches hittability once the chip is already on screen.
    /// - Parameters:
    ///   - chip: The chip to bring into view.
    ///   - app: The application under test.
    ///   - maxSwipes: How many horizontal swipes to attempt before giving up.
    @discardableResult
    private func scrollChipIntoView(_ chip: XCUIElement, in app: XCUIApplication, maxAttempts: Int = 6) -> Bool {
        // Two problems with a plain `swipeLeft()` loop here, both measured against the real
        // app rather than assumed:
        // 1. `app.scrollViews.firstMatch` is *not* reliably the chip row — this screen has
        //    three scroll views (a ~40pt one above the chip row, the chip row itself, and the
        //    tall vertical feed below) and enumeration order doesn't put the chip row first.
        //    Swiping the wrong one is a silent no-op.
        // 2. A default `swipeLeft()` drags ~85% of the element's width — roughly 670pt on
        //    this ~790pt-wide row — while a chip that's off the initial viewport is typically
        //    only a few points past the edge. One swipe blows straight through the "now
        //    visible" window and out the other side; the loop then has no way back since it
        //    only ever swipes in one direction.
        // So this drags by a *measured* distance instead of a fixed-ratio gesture, and
        // recomputes after each attempt (self-correcting if the drag doesn't land exactly).
        guard chip.exists else { return false }
        let chipY = chip.frame.midY
        let navBar = app.scrollViews.allElementsBoundByIndex.first {
            $0.frame.minY <= chipY && chipY <= $0.frame.maxY
        } ?? app.scrollViews.firstMatch
        var attempts = 0
        while attempts < maxAttempts, chip.exists, !app.frame.contains(chip.frame) {
            let overflowRight = chip.frame.maxX - app.frame.maxX
            let overflowLeft = app.frame.minX - chip.frame.minX
            let margin: CGFloat = 24
            let dx: CGFloat
            if overflowRight > 0 {
                dx = -(overflowRight + margin) // drag left: reveal content further right
            } else if overflowLeft > 0 {
                dx = overflowLeft + margin // drag right: reveal content further left
            } else {
                break
            }
            let start = navBar.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            let end = start.withOffset(CGVector(dx: dx, dy: 0))
            start.press(forDuration: 0.05, thenDragTo: end)
            attempts += 1
        }
        return chip.exists && app.frame.contains(chip.frame)
    }

    /// Finds, scrolls to, and taps a Sports hub chip, then settles.
    /// - Parameters:
    ///   - text: The substring identifying the chip (e.g. "Live", "MLB").
    ///   - app: The application under test.
    private func tapSportsChip(containing text: String, in app: XCUIApplication) {
        let chip = sportsChip(containing: text, in: app)
        XCTAssertTrue(chip.waitForExistence(timeout: UIWait.load), "No '\(text)' chip")
        XCTAssertTrue(scrollChipIntoView(chip, in: app), "'\(text)' chip never scrolled into view")
        chip.tap()
        settle(app)
    }

    /// Taps a sub-tab in the World Cup hub's pill selector (Games / Props / Bracket / Map).
    /// Each of these is a plain `Text` label with nothing else composed in, so an exact
    /// match is correct and needs no change from the v1 predicate.
    private func selectSubTab(_ label: String, in app: XCUIApplication) {
        let tab = app.buttons[label]
        XCTAssertTrue(tab.waitForHittable(timeout: UIWait.ui), "No '\(label)' sub-tab")
        tab.tap()
        settle(app)
    }

    func test_sportsHubCatalogue() {
        let app = sportsHub()
        capture("sports_hub_catalogue", of: app)
    }

    func test_homeSportsLive() {
        let app = sportsHub()
        tapSportsChip(containing: "Live", in: app)
        capture("home_sports_live", of: app)
    }

    func test_homeSportsMLB() {
        let app = sportsHub()
        // Not event-dependent: MLB's regular season is running at the time this suite runs
        // (early September), so an absent chip here is a real regression, not a quiet-data
        // state — assert, don't skip (the assertions live inside `tapSportsChip`).
        tapSportsChip(containing: "MLB", in: app)
        capture("home_sports_mlb", of: app)
    }

    func test_homeSportsFutures() {
        let app = sportsHub()
        tapSportsChip(containing: "Futures", in: app)
        capture("home_sports_futures", of: app)
    }

    func test_homeSportsWorldCup() throws {
        let app = sportsHub()
        // The World Cup chip only appears in this nav bar when the sport catalogue reports
        // an active event under it. The 2026 tournament has concluded, so this chip is
        // expected to be absent most of the time — skip rather than mis-capture whichever
        // chip happens to be first.
        let worldCup = sportsChip(containing: "World Cup", in: app)
        try requireMarket(worldCup, named: "home_sports_worldcup")
        scrollChipIntoView(worldCup, in: app)
        worldCup.tap()
        settle(app)
        capture("home_sports_worldcup", of: app)
    }

    func test_teamProfile() {
        let app = sportsHub()
        tapSportsChip(containing: "MLB", in: app)

        // There is no combined "Team A vs Team B" row to match on: `GameCard` renders each
        // team as its own separately-tappable button (label = the team name, plus its
        // win-loss record when loaded, e.g. "Pittsburgh Pirates, 68-72" — confirmed by
        // dumping every button's label on this exact screen). That record means a digit-based
        // exclusion filter (the first thing tried here) throws every real team button out too
        // — it fell through to matching the "Home" tab button instead, tapping it as a no-op
        // and leaving `team_profile.png` an exact duplicate of `home_sports_mlb.png`. Team
        // names aren't known ahead of time (live data), so instead: exclude price buttons
        // ("NRF, 50¢") and the card's own outer button ("Top 6th, $466K Vol, 0, 4") by
        // content, and everything else on screen (tab bar, category rail, chip row, search/
        // trophy icons, Games/Props toggle) by *position* — every one of those sits above the
        // games feed or in the bottom tab bar, a band real team rows never occupy.
        let candidate = app.buttons.allElementsBoundByIndex.first { button in
            let label = button.label
            let y = button.frame.minY
            return !label.contains("¢") && !label.contains("Vol") && y > 300 && y < 850
        }
        guard let teamButton = candidate else {
            XCTFail("No team row to open")
            return
        }
        XCTAssertTrue(teamButton.waitForHittable(timeout: UIWait.load), "No team row to open")
        teamButton.tap()
        settle(app)
        capture("team_profile", of: app)
    }

    func test_homeWorldCup() throws {
        let app = launchForScreenshots(preselecting: "world-cup", tagID: WorldCupTag.id)
        settle(app, timeout: UIWait.firstLoad)
        // Default landing tab is Games. With the tournament concluded, `gamesByDay` is
        // expected to be empty (or the whole hub failed to load), rendering "No games
        // scheduled" / an error state instead of real content — not a usable screenshot.
        try requireMarket(app.anyVolumeLabel, named: "home_world_cup")
        capture("home_world_cup", of: app)
    }

    func test_homeWorldCupMap() throws {
        let app = launchForScreenshots(preselecting: "world-cup", tagID: WorldCupTag.id)
        settle(app, timeout: UIWait.firstLoad)
        selectSubTab("Map", in: app)
        // The globe's pills come from the tournament-winner market's per-country outcomes.
        // In practice that market is still reachable post-tournament (it resolves rather than
        // disappearing — confirmed by this shot's own runs, which show Spain at 100%), but if
        // it's ever unavailable `MapView` renders "No odds yet" instead of the SceneKit globe,
        // which itself exposes no queryable text — so check for that empty state directly
        // rather than for absent positive content.
        let noOdds = app.staticTexts["No odds yet"]
        if noOdds.waitForExistence(timeout: UIWait.load) {
            throw XCTSkip("SKIPPED-SHOT home_worldcup_map: the market is not currently live")
        }
        capture("home_worldcup_map", of: app)
    }

    func test_homeWorldCupGame() throws {
        let app = launchForScreenshots(preselecting: "world-cup", tagID: WorldCupTag.id)
        settle(app, timeout: UIWait.firstLoad)
        // No "vs" text exists on a game card (see test_teamProfile). Tapping the card's own
        // "Vol" caption (part of the outer NavigationLink, not the inner team-tap button) is
        // the proven way to open the event detail without hitting a team profile instead —
        // see testWorldCupGameCard_tapTeamLogo_opensProfile_tapElsewhere_opensEvent.
        try requireMarket(app.anyVolumeLabel, named: "home_worldcup_game")
        app.anyVolumeLabel.tap()
        settle(app)
        capture("home_worldcup_game", of: app)
    }

    func test_homeWorldCupProps() throws {
        let app = launchForScreenshots(preselecting: "world-cup", tagID: WorldCupTag.id)
        settle(app, timeout: UIWait.firstLoad)
        selectSubTab("Props", in: app)
        // PropsListView renders "No markets" when its filtered event list is empty.
        try requireMarket(app.anyVolumeLabel, named: "home_worldcup_props")
        capture("home_worldcup_props", of: app)
    }

    func test_homeWorldCupBracket() throws {
        let app = launchForScreenshots(preselecting: "world-cup", tagID: WorldCupTag.id)
        settle(app, timeout: UIWait.firstLoad)
        // The "Bracket" tab button itself always exists (it's a static case in
        // `WorldCupTab`, not data-driven) — guarding its presence would never skip. What can
        // legitimately be absent is the bracket's *content*: `BracketBuilder.pages` renders
        // "No bracket yet" once the tournament has no current/prior-round games to show.
        selectSubTab("Bracket", in: app)
        let noBracket = app.staticTexts["No bracket yet"]
        if noBracket.waitForExistence(timeout: UIWait.load) {
            throw XCTSkip("SKIPPED-SHOT home_worldcup_bracket: the market is not currently live")
        }
        capture("home_worldcup_bracket", of: app)
    }

    func test_worldCupFranchiseWinner() throws {
        let app = launchForScreenshots(preselecting: "world-cup", tagID: WorldCupTag.id)
        settle(app, timeout: UIWait.firstLoad)
        // The winner/futures markets live under the Props tab, not the default Games tab —
        // searching for "Winner" text without first switching tabs never finds anything.
        selectSubTab("Props", in: app)
        let winner = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Winner")).firstMatch
        // `PropsListView`'s `LazyVStack` only materializes rows near the viewport, so a
        // "Winner" market further down the list doesn't exist in the accessibility tree yet
        // to `requireMarket` — scroll toward it first (best-effort; `scrollTo` gives up after
        // `maxSwipes` either way), matching the pattern `HomeShots.test_homeTrendingWorldCupWinners`
        // already established, then check.
        app.scrollTo(winner, maxSwipes: 15)
        try requireMarket(winner, named: "worldcup_franch_winner")
        XCTAssertTrue(app.scrollTo(winner), "Never reached the Winner market")
        settle(app)
        capture("worldcup_franch_winner", of: app)
    }

    func test_homeSportsWimbledon() throws {
        let app = sportsHub()
        let wimbledon = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Wimbledon")).firstMatch
        try requireMarket(wimbledon, named: "home_sports_wimbledon")
        scrollChipIntoView(wimbledon, in: app)
        wimbledon.tap()
        settle(app)
        capture("home_sports_wimbledon", of: app)
    }
}
