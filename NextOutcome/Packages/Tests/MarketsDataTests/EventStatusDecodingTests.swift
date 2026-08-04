import XCTest
@testable import MarketsData
@testable import MarketsDomain

/// Gamma's fixture-status flags. The load-bearing fact: `ended` is orthogonal to `closed` —
/// a finished match awaiting UMA resolution comes back `ended: true, closed: false`, so the
/// `closed=false` list filter does *not* keep finished games out of the feed. See
/// `docs/polymarket-data-freshness.md` §7.
final class EventStatusDecodingTests: XCTestCase {
    /// A real finished esports match: `ended` is true while `closed`/`active` still say tradeable.
    func test_endedFixture_isEndedDespiteClosedBeingFalse() throws {
        let json = """
        {"id":"756180","title":"LoL: Gen.G vs Hanwha Life Esports","slug":"lol-gen-hle1-2026-08-03",
         "volume":"0","markets":[],
         "ended":true,"live":false,"closed":false,"active":true}
        """.data(using: .utf8)!
        let event = MarketMapper.event(from: try JSONDecoder().decode(EventDTO.self, from: json))
        XCTAssertTrue(event.isEnded)
        XCTAssertFalse(event.isLive)
    }

    /// An in-play match: `live` true, `ended` false.
    func test_liveFixture_isLiveNotEnded() throws {
        let json = """
        {"id":"1","title":"LoL: Nongshim Red Force vs T1","slug":"lol-ns-t1-2026-08-03",
         "volume":"0","markets":[],
         "ended":false,"live":true,"closed":false,"active":true}
        """.data(using: .utf8)!
        let event = MarketMapper.event(from: try JSONDecoder().decode(EventDTO.self, from: json))
        XCTAssertFalse(event.isEnded)
        XCTAssertTrue(event.isLive)
    }

    /// Ordinary (non-fixture) markets omit both flags entirely — `nil` must read as
    /// "not a fixture", never as ended.
    func test_ordinaryMarket_withoutFlags_isNeitherLiveNorEnded() throws {
        let json = """
        {"id":"2","title":"Fed decision in September?","slug":"fed-decision-in-september-762",
         "volume":"0","markets":[],"closed":false}
        """.data(using: .utf8)!
        let event = MarketMapper.event(from: try JSONDecoder().decode(EventDTO.self, from: json))
        XCTAssertFalse(event.isEnded)
        XCTAssertFalse(event.isLive)
    }

    /// Polymarket's own fallback: when `ended` is absent but the event is closed, treat it
    /// as ended (and never as live).
    func test_closedWithoutEndedFlag_fallsBackToEnded() throws {
        let json = """
        {"id":"3","title":"Resolved event","slug":"resolved","volume":"0","markets":[],
         "closed":true}
        """.data(using: .utf8)!
        let event = MarketMapper.event(from: try JSONDecoder().decode(EventDTO.self, from: json))
        XCTAssertTrue(event.isEnded)
        XCTAssertFalse(event.isLive)
    }

    /// An explicit `ended: false` wins over `closed: true` rather than being overridden by
    /// the fallback.
    func test_explicitEndedFalse_beatsClosedFallback() throws {
        let json = """
        {"id":"4","title":"Odd but possible","slug":"odd","volume":"0","markets":[],
         "ended":false,"closed":true}
        """.data(using: .utf8)!
        let event = MarketMapper.event(from: try JSONDecoder().decode(EventDTO.self, from: json))
        XCTAssertFalse(event.isEnded)
    }
}
