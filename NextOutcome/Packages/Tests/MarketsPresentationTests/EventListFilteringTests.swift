//
//  EventListFilteringTests.swift
//  NextOutcome
//

import XCTest
@testable import MarketsPresentation
import MarketsDomain
import DesignSystem

@MainActor
final class EventListFilteringTests: XCTestCase {
    private func tag(_ label: String) -> Tag { Tag(id: "id-\(label)", label: label, slug: label.lowercased()) }

    func test_tagID_forCategory_usesStableIDs() {
        // The category rail resolves to stable Gamma tag ids, independent of the
        // near-empty carousel-tags list (which previously made every chip no-op).
        XCTAssertNil(EventListViewModel.tagID(for: .trending))
        XCTAssertEqual(EventListViewModel.tagID(for: .worldCup), "519")
        XCTAssertEqual(EventListViewModel.tagID(for: .breaking), "198")
        XCTAssertEqual(EventListViewModel.tagID(for: .politics), "2")
        XCTAssertEqual(EventListViewModel.tagID(for: .sports), "1")
    }

    func test_tagID_forCategory_matchesBySlugOrLabel() {
        let tags = [tag("Politics"), tag("Sports"), tag("Crypto")]
        XCTAssertEqual(EventListViewModel.tagID(for: .politics, in: tags), "id-Politics")
        XCTAssertEqual(EventListViewModel.tagID(for: .sports, in: tags), "id-Sports")
        XCTAssertNil(EventListViewModel.tagID(for: .trending, in: tags)) // trending = no filter
    }

    func test_tagID_missingTag_isNil() {
        XCTAssertNil(EventListViewModel.tagID(for: .politics, in: [tag("Sports")]))
    }

    func test_visibleEvents_hideSports_dropsSportsEvents() async {
        let vm = EventListViewModel.makeForTesting(events: [
            Event(id: "1", title: "Game", slug: "g", markets: [], volume: 0, imageURL: nil,
                  tags: [tag("Soccer")]),
            Event(id: "2", title: "Vote", slug: "v", markets: [], volume: 0, imageURL: nil,
                  tags: [tag("Politics")])
        ])
        XCTAssertEqual(vm.visibleEvents.map(\.id), ["1", "2"])
        vm.toggleHideSports()
        XCTAssertEqual(vm.visibleEvents.map(\.id), ["2"])
    }
}
