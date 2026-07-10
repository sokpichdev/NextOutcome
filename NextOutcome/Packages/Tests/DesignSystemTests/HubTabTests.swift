import XCTest
import SwiftUI
@testable import DesignSystem

final class HubTabTests: XCTestCase {
    func test_pinned_isInScreenshotOrder() {
        XCTAssertEqual(
            HubTab.pinned.map(\.id),
            ["trending", "world-cup", "breaking", "politics", "sports"]
        )
    }

    func test_pinned_titlesAndTagIDs() {
        XCTAssertEqual(HubTab.trending.title, "Trending")
        XCTAssertNil(HubTab.trending.tagID)
        XCTAssertEqual(HubTab.worldCup.title, "World Cup")
        XCTAssertEqual(HubTab.worldCup.tagID, "519")
        XCTAssertEqual(HubTab.breaking.tagID, "198")
        XCTAssertEqual(HubTab.politics.tagID, "2")
        XCTAssertEqual(HubTab.sports.tagID, "1")
    }

    func test_curatedAdditional_hasElevenCategoriesInOrder() {
        XCTAssertEqual(
            HubTab.curatedAdditional.map(\.slug),
            ["crypto", "esports", "finance", "geopolitics", "tech", "pop-culture",
             "economy", "weather", "election", "art", "iran"]
        )
        XCTAssertEqual(HubTab.curatedAdditional.first(where: { $0.slug == "pop-culture" })?.title, "Culture")
    }

    func test_equality_isByIDOnly() {
        let a = HubTab(id: "x", title: "A", glyph: nil, activeColor: .red, tagID: "1")
        let b = HubTab(id: "x", title: "B", glyph: "star", activeColor: .blue, tagID: "2")
        XCTAssertEqual(a, b)
    }
}
