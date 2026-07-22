//
//  UITestHelpers.swift
//  NextOutcome
//
//  Created by Sok Pich on 19/07/2026.
//
//  Shared launch, wait, scroll, and screenshot utilities for the UI suite.
//  The app has no accessibilityIdentifiers yet, so every helper works off
//  visible labels and structural queries (see docs/ui-testing/NextOutcome-UI-Test-Suite.md).
//

import XCTest

/// Timeouts tuned for the live-network reality of this app (no mocks).
enum UIWait {
    /// First content load on a freshly launched app (Gamma/data API round trips).
    static let firstLoad: TimeInterval = 45
    /// Subsequent loads once the app is warm.
    static let load: TimeInterval = 20
    /// Pure UI transitions (pushes, toggles) that need no network.
    static let ui: TimeInterval = 10
}

extension XCUIApplication {

    /// Launches the app plainly, landing on Home ▸ Trending.
    static func launched() -> XCUIApplication {
        let app = XCUIApplication()
        app.launch()
        return app
    }

    /// Launches deep-linked into a category hub via the DEBUG-only
    /// `-preselectCategory <slug> <tagID>` argument handled in RootView.
    static func launched(preselecting slug: String, tagID: String,
                         extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-preselectCategory", slug, tagID]
        app.launchArguments += extraArguments
        app.launch()
        return app
    }

    /// The four tab-bar buttons in order. The Portfolio tab's label is the
    /// live balance string (e.g. "$7.02"), so callers must use these
    /// positional accessors instead of label matching for tab 4.
    var homeTab: XCUIElement { tabBars.buttons.element(boundBy: 0) }
    var searchTab: XCUIElement { tabBars.buttons.element(boundBy: 1) }
    var breakingTab: XCUIElement { tabBars.buttons.element(boundBy: 2) }
    var portfolioTab: XCUIElement { tabBars.buttons.element(boundBy: 3) }

    /// The Search tab's query input. It is a plain `TextField`, not a system search
    /// field: the app hides the navigation bar in favour of its custom top bar, so
    /// `.searchable` renders nothing and `app.searchFields` is always empty. Matched by
    /// identifier rather than type or placeholder.
    var searchField: XCUIElement { textFields["search.field"] }

    /// Any static text whose label contains "Vol" — the volume caption every
    /// market/event card renders. The cheapest content-agnostic proof that a
    /// feed of real cards is on screen.
    var anyVolumeLabel: XCUIElement {
        staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Vol")).firstMatch
    }

    /// The nav-bar back button, if a push happened.
    var backButton: XCUIElement {
        navigationBars.buttons.matching(identifier: "Back").firstMatch
    }

    /// Pops the top of the navigation stack, falling back to the
    /// interactive-pop edge swipe when the bar button is hidden.
    func goBack() {
        if backButton.exists {
            backButton.tap()
        } else {
            swipeRight()
        }
    }

    /// Performs the pull-to-refresh gesture on the frontmost scroll view.
    func pullToRefresh() {
        let scroll = scrollViews.firstMatch.exists ? scrollViews.firstMatch : self
        let start = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25))
        let end = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9))
        start.press(forDuration: 0.15, thenDragTo: end)
    }

    /// Scrolls down until `element` is hittable or `maxSwipes` is exhausted.
    @discardableResult
    func scrollTo(_ element: XCUIElement, maxSwipes: Int = 8) -> Bool {
        var swipes = 0
        while !element.isHittable && swipes < maxSwipes {
            swipeUp()
            swipes += 1
        }
        return element.isHittable
    }
}

extension XCTestCase {

    /// Attaches a named, always-kept screenshot of the app to the test report.
    func attachScreenshot(of app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Waits for `element` and fails the test with `message` if it never appears.
    func assertAppears(_ element: XCUIElement,
                       timeout: TimeInterval,
                       _ message: String,
                       file: StaticString = #filePath,
                       line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), message,
                      file: file, line: line)
    }
}
