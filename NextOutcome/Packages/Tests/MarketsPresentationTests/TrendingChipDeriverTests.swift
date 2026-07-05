//
//  TrendingChipDeriverTests.swift
//  NextOutcome
//

import XCTest
@testable import MarketsPresentation
import MarketsDomain

final class TrendingChipDeriverTests: XCTestCase {
    private func tag(_ label: String, id: String? = nil) -> Tag {
        Tag(id: id ?? "id-\(label)", label: label, slug: label.lowercased().replacingOccurrences(of: " ", with: "-"))
    }

    private func event(_ id: String, tags: [Tag]) -> Event {
        Event(id: id, title: "e\(id)", slug: "e\(id)", markets: [], volume: 0, imageURL: nil, tags: tags)
    }

    func test_chips_rankByFrequencyThenLabel() {
        let trump = tag("Trump"), nba = tag("NBA Offseason"), iran = tag("Iran")
        let events = [
            event("1", tags: [trump, nba]),
            event("2", tags: [trump, iran]),
            event("3", tags: [trump, nba]),
            event("4", tags: [iran]),
        ]
        // trump=3, then iran=2 / nba=2 tie broken alphabetically ("Iran" < "NBA Offseason").
        XCTAssertEqual(
            TrendingChipDeriver.chips(from: events, minCount: 1).map(\.label),
            ["Trump", "Iran", "NBA Offseason"]
        )
    }

    func test_chips_excludeGenericTags_bySlugAndLabel() {
        let events = [
            event("1", tags: [tag("Sports"), tag("Politics"), tag("Trump"), tag("Trending")]),
            event("2", tags: [tag("Sports"), tag("Trump")]),
        ]
        XCTAssertEqual(TrendingChipDeriver.chips(from: events).map(\.label), ["Trump"])
    }

    func test_chips_capAtMax() {
        let tags = (0..<12).map { tag("Tag\($0)") }
        let events = [event("1", tags: tags), event("2", tags: tags)]
        XCTAssertEqual(TrendingChipDeriver.chips(from: events, max: 8).count, 8)
    }

    func test_chips_minCountDropsOneOffs_whenEnoughSurvive() {
        let frequent = (0..<4).map { tag("Hot\($0)") }
        let events = [
            event("1", tags: frequent + [tag("Rare")]),
            event("2", tags: frequent),
        ]
        let labels = TrendingChipDeriver.chips(from: events).map(\.label)
        XCTAssertEqual(labels.count, 4)
        XCTAssertFalse(labels.contains("Rare"))
    }

    func test_chips_minCountFallsBack_whenTooFewSurvive() {
        // Only one tag appears twice — below the 4-chip threshold, so one-offs are kept.
        let events = [
            event("1", tags: [tag("Hot"), tag("Rare A")]),
            event("2", tags: [tag("Hot"), tag("Rare B")]),
        ]
        let labels = TrendingChipDeriver.chips(from: events).map(\.label)
        XCTAssertEqual(labels, ["Hot", "Rare A", "Rare B"])
    }

    func test_chips_deduplicateByTagID() {
        let shared = tag("Trump", id: "t1")
        let events = [event("1", tags: [shared]), event("2", tags: [shared])]
        XCTAssertEqual(TrendingChipDeriver.chips(from: events, minCount: 1).count, 1)
    }
}
