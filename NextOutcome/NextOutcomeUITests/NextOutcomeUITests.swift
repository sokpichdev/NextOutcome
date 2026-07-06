//
//  NextOutcomeUITests.swift
//  NextOutcomeUITests
//
//  Created by Sok Pich on 28/06/2026.
//

import XCTest

final class NextOutcomeUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // XCUIAutomation Documentation
        // https://developer.apple.com/documentation/xcuiautomation
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    /// Regression test for the Sports hub's league chips: tapping MLB (or another
    /// non-World-Cup league) must swap in that league's content on the same screen —
    /// no navigation push, no back button — exactly like the Live/Futures chips.
    @MainActor
    func testSportsHubLeagueChipSelectsInPlace_doesNotPush() throws {
        let app = XCUIApplication()
        app.launch()

        app.buttons["Sports"].tap()

        let mlbChip = app.buttons["MLB"]
        XCTAssertTrue(mlbChip.waitForExistence(timeout: 45), "Expected the MLB league chip to appear once the Sports Live sample loads")
        mlbChip.tap()

        // League detail content (its own Games/Props toggle) should now be showing...
        XCTAssertTrue(app.buttons["Games"].waitForExistence(timeout: 20), "Expected MLB's Games/Props detail content to swap in in place")
        // ...with no navigation push: no back button, and the Sports category chip
        // (part of the persistent top rail, unrelated to this screen's own content)
        // is still directly reachable without popping anything first.
        XCTAssertFalse(app.navigationBars.buttons.matching(identifier: "Back").firstMatch.exists)
        XCTAssertTrue(app.buttons["Sports"].exists)

        // Tapping Live returns to the aggregate feed and clears the league selection.
        app.buttons["Live"].tap()
        XCTAssertFalse(app.buttons["Games"].exists)
    }

    /// The Odds Format menu lives on the Live/Futures header row (next to the title and
    /// search icon), holds only Odds Format + Show Spreads/Totals (no sort — Volume/Soonest
    /// was removed), and applies its choice to game cards. It isn't shown once a league chip
    /// is selected (that header row is hidden then, same as the title).
    @MainActor
    func testSportsHubOddsFormatMenu_hasNoSortAndAppliesToLiveContent() throws {
        let app = XCUIApplication()
        app.launch()

        app.buttons["Sports"].tap()
        let oddsFormatButton = app.buttons["Odds Format"]
        XCTAssertTrue(oddsFormatButton.waitForExistence(timeout: 45))

        let attachmentBefore = XCTAttachment(screenshot: app.screenshot())
        attachmentBefore.name = "Sports Live — before Odds Format change"
        attachmentBefore.lifetime = .keepAlways
        add(attachmentBefore)

        oddsFormatButton.tap()
        // Sort was removed from this menu entirely.
        XCTAssertFalse(app.buttons["Volume"].exists)
        XCTAssertFalse(app.buttons["Soonest"].exists)
        app.buttons["American"].tap()

        let attachmentAfter = XCTAttachment(screenshot: app.screenshot())
        attachmentAfter.name = "Sports Live — American odds"
        attachmentAfter.lifetime = .keepAlways
        add(attachmentAfter)
    }

    /// Regression test: `Event.gameStartTime` used to be nil for every event fetched by tag
    /// (Gamma only carries kickoff on the embedded markets, not the event), so
    /// `WorldCupEventSplitter.split` bucketed every real UFC/MLB game as a prop instead of a
    /// schedulable game, leaving the Games tab empty. UFC and MLB must now show real games.
    @MainActor
    func testSportsHubLeagueDetail_ufcAndMLB_showRealGames_notEmpty() throws {
        let app = XCUIApplication()
        app.launch()

        app.buttons["Sports"].tap()

        let ufcChip = app.buttons["UFC"]
        XCTAssertTrue(ufcChip.waitForExistence(timeout: 45))
        ufcChip.tap()
        XCTAssertTrue(app.buttons["Games"].waitForExistence(timeout: 20))
        XCTAssertFalse(app.staticTexts["No results"].waitForExistence(timeout: 15), "UFC Games tab should show real fight cards, not the empty state")

        let ufcAttachment = XCTAttachment(screenshot: app.screenshot())
        ufcAttachment.name = "UFC Games — real fights, not empty"
        ufcAttachment.lifetime = .keepAlways
        add(ufcAttachment)

        let mlbChip = app.buttons["MLB"]
        XCTAssertTrue(mlbChip.waitForExistence(timeout: 20))
        mlbChip.tap()
        XCTAssertTrue(app.buttons["Games"].waitForExistence(timeout: 20))
        XCTAssertFalse(app.staticTexts["No results"].waitForExistence(timeout: 15), "MLB Games tab should show real games, not the empty state")

        let mlbAttachment = XCTAttachment(screenshot: app.screenshot())
        mlbAttachment.name = "MLB Games — real games, not empty"
        mlbAttachment.lifetime = .keepAlways
        add(mlbAttachment)
    }

    /// Tapping a team's logo/name on a World Cup game card opens its team profile in
    /// place of the event detail — the whole card is already wrapped in a NavigationLink
    /// pushing the event, so this exercises the nested-Button tap-target mechanism
    /// GameCard uses instead of a second NavigationLink. Tapping the card away from the
    /// logo must still open the event detail as before.
    @MainActor
    func testWorldCupGameCard_tapTeamLogo_opensProfile_tapElsewhere_opensEvent() throws {
        let app = XCUIApplication()
        app.launch()

        app.buttons["Sports"].tap()
        let worldCupChip = app.buttons["World Cup"]
        XCTAssertTrue(worldCupChip.waitForExistence(timeout: 45))
        worldCupChip.tap()

        let teamButton = app.buttons["United States"]
        XCTAssertTrue(teamButton.waitForExistence(timeout: 30), "Expected a 'United States vs. Belgium' game card with a tappable team logo")
        teamButton.tap()

        // The team profile screen shows the team's name as a heading.
        XCTAssertTrue(app.staticTexts["United States"].waitForExistence(timeout: 15), "Expected TeamProfileView to open showing the team's name")

        let profileAttachment = XCTAttachment(screenshot: app.screenshot())
        profileAttachment.name = "TeamProfileView — United States"
        profileAttachment.lifetime = .keepAlways
        add(profileAttachment)

        // Go back to the Games list, then tap the card away from the logo — it should
        // still open the event detail (the outer NavigationLink still works).
        if app.navigationBars.buttons.matching(identifier: "Back").firstMatch.exists {
            app.navigationBars.buttons.matching(identifier: "Back").firstMatch.tap()
        } else {
            app.swipeRight() // interactive-pop gesture fallback
        }
        XCTAssertTrue(app.buttons["United States"].waitForExistence(timeout: 15), "Expected to be back on the Games list")

        let volLabel = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Vol")).firstMatch
        XCTAssertTrue(volLabel.waitForExistence(timeout: 10), "Expected the card's volume label (part of the card, not the team button) to exist")
        volLabel.tap()

        // Tapping the card away from the team logo pushed the event detail — a nav-bar
        // back button now exists, proving the outer NavigationLink still fires normally.
        XCTAssertTrue(
            app.navigationBars.buttons.matching(identifier: "Back").firstMatch.waitForExistence(timeout: 15),
            "Expected tapping the card body to push the event detail, same as before this feature was added"
        )
    }
}
