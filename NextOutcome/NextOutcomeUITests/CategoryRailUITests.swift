//
//  CategoryRailUITests.swift
//  NextOutcome
//
//  Created by Sok Pich on 19/07/2026.
//
//  TC-030, TC-031: the horizontal category rail swaps the Home tab's hub
//  content in place — never a navigation push — for every pinned chip, and
//  swipes to reveal the runtime-curated chips (Crypto, Esports, …).
//

import XCTest

final class CategoryRailUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// TC-030: each pinned chip selects in place. After every tap the rail is
    /// still present, no Back button appeared, and the hub's content anchor
    /// eventually shows.
    @MainActor
    func testPinnedChipsSwapInPlace() throws {
        let app = XCUIApplication.launched()
        assertAppears(app.buttons["Trending"], timeout: UIWait.ui, "Rail should be visible")

        // chip label → an anchor that proves that hub rendered.
        // Breaking rows expose "… percent over 24 hours"; Sports shows the
        // Odds Format menu; World Cup and Politics render market cards (Vol).
        let hubs: [(chip: String, anchor: () -> XCUIElement)] = [
            ("World Cup", { app.anyVolumeLabel }),
            ("Breaking", { app.staticTexts
                .matching(NSPredicate(format: "label CONTAINS[c] %@", "percent over 24 hours"))
                .firstMatch }),
            ("Politics", { app.anyVolumeLabel }),
            ("Sports", { app.buttons["Odds Format"] }),
            ("Trending", { app.anyVolumeLabel }),
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

    /// TC-031: the rail scrolls horizontally to reveal curated chips resolved
    /// at runtime from Gamma tags (Crypto, Esports, Finance, …).
    @MainActor
    func testRailScrollsToCuratedChips() throws {
        let app = XCUIApplication.launched()
        let trendingChip = app.buttons["Trending"]
        assertAppears(trendingChip, timeout: UIWait.ui, "Rail should be visible")

        // Curated chips need a network round trip to resolve; give the first
        // one time to exist in the hierarchy before swiping to it.
        let cryptoChip = app.buttons["Crypto"]
        _ = cryptoChip.waitForExistence(timeout: UIWait.firstLoad)

        // Swipe the rail itself (start from the Trending chip so we drag the
        // horizontal scroller, not the vertical feed).
        var swipes = 0
        while !cryptoChip.isHittable && swipes < 6 {
            trendingChip.coordinate(withNormalizedOffset: CGVector(dx: 2.5, dy: 0.5))
                .press(forDuration: 0.1,
                       thenDragTo: trendingChip.coordinate(withNormalizedOffset: .zero))
            swipes += 1
        }

        XCTAssertTrue(cryptoChip.exists,
                      "The curated 'Crypto' chip should be reachable by swiping the rail")
        attachScreenshot(of: app, named: "Rail — curated chips revealed")

        cryptoChip.tap()
        XCTAssertFalse(app.backButton.exists, "Curated chips also select in place")
    }
}
