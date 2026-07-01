import XCTest
@testable import MarketsData
@testable import MarketsDomain

final class EventTagsDecodingTests: XCTestCase {
    func test_eventDecodesTagsAndMapsThem() throws {
        let json = """
        {"id":"e1","title":"World Cup Winner","slug":"wc","volume":"100",
         "markets":[],
         "tags":[{"id":"1","label":"Sports","slug":"sports"},
                 {"id":"2","label":"Soccer","slug":"soccer"}]}
        """.data(using: .utf8)!
        let dto = try JSONDecoder().decode(EventDTO.self, from: json)
        let event = MarketMapper.event(from: dto)
        XCTAssertEqual(event.tags.map(\.label), ["Sports", "Soccer"])
    }

    func test_eventWithoutTagsDefaultsToEmpty() throws {
        let json = """
        {"id":"e2","title":"No Tags","slug":"nt","volume":"0","markets":[]}
        """.data(using: .utf8)!
        let dto = try JSONDecoder().decode(EventDTO.self, from: json)
        XCTAssertTrue(MarketMapper.event(from: dto).tags.isEmpty)
    }
}
