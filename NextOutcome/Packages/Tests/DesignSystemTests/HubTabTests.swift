import XCTest
import SwiftUI
@testable import DesignSystem

final class HubTabTests: XCTestCase {
    func test_all_sendsNoTagFilter() {
        // Gamma has a real "all" tag (id 100215), but filtering by it returns only the couple
        // of events literally tagged "all" — not the whole feed. The default tab must send
        // no tag at all, so this assertion is the guard against a very quiet regression.
        XCTAssertEqual(HubTab.all.id, "all")
        XCTAssertEqual(HubTab.all.title, "All")
        XCTAssertNil(HubTab.all.tagID)
    }

    func test_fallbackNav_leadsWithAllAndIsSlugKeyed() {
        XCTAssertEqual(HubTab.fallbackNav.first, HubTab.all)
        // Every entry is keyed by its Gamma slug so a fetched tab replaces it cleanly.
        XCTAssertEqual(
            HubTab.fallbackNav.map(\.id),
            ["all", "politics", "sports", "crypto", "finance", "geopolitics",
             "tech", "pop-culture", "economy", "weather", "elections"]
        )
    }

    func test_fallbackNav_isTextOnly() {
        // Fetched tags carry no glyph, so the fallback must not either — otherwise the rail
        // visibly changes shape the moment the live row arrives.
        XCTAssertTrue(HubTab.fallbackNav.allSatisfy { $0.glyph == nil })
    }

    func test_routeIdentifiers_matchTheirGammaSlugs() {
        // These exist only so RootView can match the selected tab against a bespoke hub.
        XCTAssertEqual(HubTab.politics.id, "politics")
        XCTAssertEqual(HubTab.sports.id, "sports")
        XCTAssertEqual(HubTab.worldCup.id, "world-cup")
        XCTAssertEqual(HubTab.breaking.id, "breaking")
    }

    func test_equality_isByIDOnly() {
        let a = HubTab(id: "x", title: "A", glyph: nil, activeColor: .red, tagID: "1")
        let b = HubTab(id: "x", title: "B", glyph: "star", activeColor: .blue, tagID: "2")
        XCTAssertEqual(a, b)
    }

    func test_fetchedTab_matchesRouteIdentifier() {
        // The load-bearing consequence of id-only equality: a tab built from the fetched
        // nav row routes to the bespoke hub without any id bookkeeping.
        let fetched = HubTab(id: "sports", title: "Sports", glyph: nil,
                             activeColor: .primary, tagID: "1")
        XCTAssertEqual(fetched, HubTab.sports)
    }
}
