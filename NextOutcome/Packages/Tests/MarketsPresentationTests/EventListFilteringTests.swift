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
