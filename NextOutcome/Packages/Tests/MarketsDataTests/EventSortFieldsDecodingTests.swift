import XCTest
@testable import MarketsData
@testable import MarketsDomain

final class EventSortFieldsDecodingTests: XCTestCase {
    func test_eventDecodesAllFourSortFields() throws {
        let json = """
        {"id":"e1","title":"Bitcoin above ___ on July 10?","slug":"btc-above","volume":"100",
         "markets":[],
         "volume24hr":"1723978.62","liquidity":"978901.93","competitive":0.9296920395119117,
         "creationDate":"2026-07-03T16:01:37.029304Z"}
        """.data(using: .utf8)!
        let dto = try JSONDecoder().decode(EventDTO.self, from: json)
        let event = MarketMapper.event(from: dto)
        XCTAssertEqual(event.volume24hr, Decimal(string: "1723978.62"))
        XCTAssertEqual(event.liquidity, Decimal(string: "978901.93"))
        XCTAssertEqual(event.competitive, 0.9296920395119117)
        XCTAssertNotNil(event.creationDate)
    }

    func test_eventWithoutSortFields_defaultsSafely() throws {
        let json = """
        {"id":"e2","title":"No Sort Fields","slug":"nsf","volume":"0","markets":[]}
        """.data(using: .utf8)!
        let dto = try JSONDecoder().decode(EventDTO.self, from: json)
        let event = MarketMapper.event(from: dto)
        XCTAssertEqual(event.volume24hr, 0)
        XCTAssertEqual(event.liquidity, 0)
        XCTAssertNil(event.competitive)
        XCTAssertNil(event.creationDate)
    }
}
