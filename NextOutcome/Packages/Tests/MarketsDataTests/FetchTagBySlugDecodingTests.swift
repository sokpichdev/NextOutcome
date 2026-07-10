import XCTest
import Foundation
@testable import MarketsData
import MarketsDomain

final class FetchTagBySlugDecodingTests: XCTestCase {
    /// Gamma's `GET /tags/slug/{slug}` returns a single JSON object (not an array),
    /// unlike `/tags`. Confirms `TagDTO` decodes directly from that shape and maps
    /// to the expected domain `Tag`.
    func test_tagDTO_decodesSingleObject_andMapsToTag() throws {
        let json = """
        {"id":"21","label":"Crypto","slug":"crypto","forceShow":true}
        """.data(using: .utf8)!

        let dto = try JSONDecoder().decode(TagDTO.self, from: json)
        let tag = MarketMapper.tag(from: dto)

        XCTAssertEqual(tag.id, "21")
        XCTAssertEqual(tag.label, "Crypto")
        XCTAssertEqual(tag.slug, "crypto")
    }
}
