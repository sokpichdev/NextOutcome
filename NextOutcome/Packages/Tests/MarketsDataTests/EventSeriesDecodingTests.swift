import XCTest
@testable import MarketsData
@testable import MarketsDomain

final class EventSeriesDecodingTests: XCTestCase {
    func test_eventDecodesSeriesSlugAsRecurrence() throws {
        let json = """
        {"id":"e1","title":"BTC Up or Down 5m","slug":"btc-5m","volume":"100",
         "markets":[],
         "series":[{"slug":"btc-up-or-down-5m"}]}
        """.data(using: .utf8)!
        let dto = try JSONDecoder().decode(EventDTO.self, from: json)
        let event = MarketMapper.event(from: dto)
        XCTAssertEqual(event.recurrence, "btc-up-or-down-5m")
    }

    func test_eventWithoutSeriesDefaultsRecurrenceToNil() throws {
        let json = """
        {"id":"e2","title":"No Series","slug":"ns","volume":"0","markets":[]}
        """.data(using: .utf8)!
        let dto = try JSONDecoder().decode(EventDTO.self, from: json)
        XCTAssertNil(MarketMapper.event(from: dto).recurrence)
    }

    func test_eventWithEmptySeriesArrayDefaultsRecurrenceToNil() throws {
        let json = """
        {"id":"e3","title":"Empty Series","slug":"es","volume":"0","markets":[],"series":[]}
        """.data(using: .utf8)!
        let dto = try JSONDecoder().decode(EventDTO.self, from: json)
        XCTAssertNil(MarketMapper.event(from: dto).recurrence)
    }
}
