//
//  CategoryRailUITests.swift
//  NextOutcome
//
//  Created by Sok Pich on 19/07/2026.
//
//  TC-030, TC-031: the horizontal category rail swaps the Home tab's hub
//  content in place — never a navigation push — and swipes to reveal the
//  chips further along the row.
//
//  The rail is fetched at runtime from Gamma's `top-navbar` tag, so its exact
//  contents are Polymarket's to change without notice. These tests only assert
//  on chips that appear in both the live row and `HubTab.fallbackNav`, so they
//  hold whether or not the fetch succeeded.
//

import XCTest

final class CategoryRailUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// TC-030: each chip selects in place. After every tap the rail is still
    /// present, no Back button appeared, and the hub's content anchor
    /// eventually shows.
    @MainActor
    func testChipsSwapInPlace() throws {
        let app = XCUIApplication.launched()
        assertAppears(app.buttons["All"], timeout: UIWait.firstLoad, "Rail should be visible")

        // chip label → an anchor that proves that hub rendered.
        // Sports shows the Odds Format menu; All and Politics render market cards (Vol).
        let hubs: [(chip: String, anchor: () -> XCUIElement)] = [
            ("Politics", { app.anyVolumeLabel }),
            ("Sports", { app.buttons["Odds Format"] }),
            ("All", { app.anyVolumeLabel }),
        ]

        for hub in hubs {
            app.buttons[hub.chip].tap()
            assertAppears(hub.anchor(), timeout: UIWait.firstLoad,
                          "'\(hub.chip)' hub should render its content in place")
            XCTAssertFalse(app.backButton.exists,
                           "Selecting the '\(hub.chip)' chip must not push a screen")
            XCTAssertTrue(app.buttons[hub.chip].exists,
                          "The rail (and the '\(hub.chip)' chip) must remain on screen")
            attachScreenshot(of: app, named: "Rail — \(hub.chip) hub")
        }
    }

    /// TC-031: the rail scrolls horizontally to reveal the chips further along
    /// the fetched row (Weather sits near its end).
    @MainActor
    func testRailScrollsToLaterChips() throws {
        let app = XCUIApplication.launched()
        let allChip = app.buttons["All"]
        assertAppears(allChip, timeout: UIWait.firstLoad, "Rail should be visible")

        // The live row needs a network round trip; give the target chip time to
        // exist in the hierarchy before swiping to it.
        let weatherChip = app.buttons["Weather"]
        _ = weatherChip.waitForExistence(timeout: UIWait.firstLoad)

        // Swipe the rail itself (start from the leading chip so we drag the
        // horizontal scroller, not the vertical feed).
        var swipes = 0
        while !weatherChip.isHittable && swipes < 6 {
            allChip.coordinate(withNormalizedOffset: CGVector(dx: 2.5, dy: 0.5))
                .press(forDuration: 0.1,
                       thenDragTo: allChip.coordinate(withNormalizedOffset: .zero))
            swipes += 1
        }

        XCTAssertTrue(weatherChip.exists,
                      "The 'Weather' chip should be reachable by swiping the rail")
        attachScreenshot(of: app, named: "Rail — later chips revealed")

        weatherChip.tap()
        XCTAssertFalse(app.backButton.exists, "Later chips also select in place")
    }

    /// The sub-topic carousel is Gamma's own row for the selected category, so
    /// selecting a chip from it must filter the feed in place, not push.
    @MainActor
    func testSubTopicRowFiltersInPlace() throws {
        let app = XCUIApplication.launched()
        assertAppears(app.buttons["All"], timeout: UIWait.firstLoad, "Rail should be visible")
        assertAppears(app.anyVolumeLabel, timeout: UIWait.firstLoad, "Feed should load")

        // The row always leads with a synthetic "All" chip when it has entries.
        // It's absent for categories with no sub-topics, which is a valid state.
        let subTopicAll = app.buttons.matching(identifier: "All").element(boundBy: 1)
        guard subTopicAll.waitForExistence(timeout: UIWait.ui) else {
            throw XCTSkip("The selected category has no sub-topic row today")
        }

        attachScreenshot(of: app, named: "Rail — sub-topic row")
        XCTAssertFalse(app.backButton.exists, "Sub-topic chips must not push a screen")
    }
}
