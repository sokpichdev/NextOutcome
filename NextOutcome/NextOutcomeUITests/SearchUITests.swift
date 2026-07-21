//
//  SearchUITests.swift
//  NextOutcome
//
//  Created by Sok Pich on 19/07/2026.
//
//  TC-100…TC-102: the Search tab — idle prompt, live results, the
//  "No results" empty state, clearing, and pushing a market detail.
//

import XCTest

final class SearchUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func openSearch(_ app: XCUIApplication) -> XCUIElement {
        app.searchTab.tap()
        let field = app.searchField
        assertAppears(field, timeout: UIWait.load, "The .searchable field should exist")
        return field
    }

    /// TC-100: a common query returns market cards.
    @MainActor
    func testSearchReturnsResults() throws {
        let app = XCUIApplication.launched()

        // Idle prompt first.
        app.searchTab.tap()
        assertAppears(app.staticTexts["Search NextOutcome markets"], timeout: UIWait.load,
                      "Idle prompt should show before typing")

        let field = app.searchField
        field.tap()
        field.typeText("election")

        assertAppears(app.anyVolumeLabel, timeout: UIWait.firstLoad,
                      "Searching 'election' should return market cards")
        attachScreenshot(of: app, named: "Search — 'election' results")
    }

    /// TC-101: a gibberish query lands on the empty state, and clearing the
    /// query restores the idle prompt.
    @MainActor
    func testSearchNoResults() throws {
        let app = XCUIApplication.launched()
        let field = openSearch(app)

        field.tap()
        field.typeText("zzqxv99gibberish")

        assertAppears(app.staticTexts["No results"], timeout: UIWait.firstLoad,
                      "A nonsense query should show the 'No results' state")
        attachScreenshot(of: app, named: "Search — no results")

        // Clear via the trailing clear button. It sits beside the field in the same HStack,
        // not inside it, so it's queried off the app rather than off `field`.
        let clear = app.buttons["Clear text"]
        if clear.exists {
            clear.tap()
        } else {
            // Fall back to deleting the query one character at a time.
            field.tap()
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 20))
        }
        assertAppears(app.staticTexts["Search NextOutcome markets"], timeout: UIWait.ui,
                      "Clearing the query should restore the idle prompt")
    }

    /// TC-102: tapping a result pushes MarketDetailView and Back returns to
    /// the still-populated results list.
    @MainActor
    func testSearchResultOpensDetail() throws {
        let app = XCUIApplication.launched()
        let field = openSearch(app)

        field.tap()
        field.typeText("world cup")

        let result = app.anyVolumeLabel
        assertAppears(result, timeout: UIWait.firstLoad, "Results should load")
        result.tap()

        assertAppears(app.backButton, timeout: UIWait.load,
                      "A result tap should push the market detail")
        attachScreenshot(of: app, named: "Search — result detail")

        app.goBack()
        assertAppears(app.anyVolumeLabel, timeout: UIWait.ui,
                      "Back should return to the intact results list")
    }
}
