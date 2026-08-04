import XCTest
@testable import MarketsData
@testable import MarketsDomain

/// A recurring market's per-window event title names one window
/// (`"Bitcoin Up or Down - August 3, 10:15AM-10:20AM ET"`); the series carries the name the
/// card should show (`"BTC Up or Down 5m"`). Payload shape verified against live Gamma.
final class SeriesTitleDecodingTests: XCTestCase {
    func test_decodesSeriesTitleAlongsideSlug() throws {
        let json = """
        {"id":"1","title":"Bitcoin Up or Down - August 3, 10:15AM-10:20AM ET",
         "slug":"btc-updown-5m-1785765300","volume":"0","markets":[],
         "series":[{"id":"10684","slug":"btc-up-or-down-5m","title":"BTC Up or Down 5m","recurrence":"5m"}]}
        """.data(using: .utf8)!
        let event = MarketMapper.event(from: try JSONDecoder().decode(EventDTO.self, from: json))
        XCTAssertEqual(event.seriesTitle, "BTC Up or Down 5m")
        // The cadence still comes from the slug suffix, not the series' `recurrence` field.
        XCTAssertEqual(event.recurrence, "btc-up-or-down-5m")
    }

    /// A series without a title must not blank the card — the view falls back to the event.
    func test_seriesWithoutTitle_leavesSeriesTitleNil() throws {
        let json = """
        {"id":"1","title":"Some Event","slug":"e","volume":"0","markets":[],
         "series":[{"slug":"btc-up-or-down-5m"}]}
        """.data(using: .utf8)!
        let event = MarketMapper.event(from: try JSONDecoder().decode(EventDTO.self, from: json))
        XCTAssertNil(event.seriesTitle)
        XCTAssertEqual(event.recurrence, "btc-up-or-down-5m")
    }

    /// One-off markets have no series at all.
    func test_eventWithoutSeries_leavesSeriesTitleNil() throws {
        let json = """
        {"id":"1","title":"Fed decision in September?","slug":"fed","volume":"0","markets":[]}
        """.data(using: .utf8)!
        let event = MarketMapper.event(from: try JSONDecoder().decode(EventDTO.self, from: json))
        XCTAssertNil(event.seriesTitle)
    }
}
