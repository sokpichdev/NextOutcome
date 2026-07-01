import XCTest
@testable import MarketsData
import MarketsDomain

final class GammaEventQueryTests: XCTestCase {
    func test_volume24h_active_hasExpectedParams() {
        let params = GammaEventQuery.params(offset: 0, tagID: nil, sort: .volume24h, status: .active)
        XCTAssertEqual(params["order"], "volume24hr")
        XCTAssertEqual(params["ascending"], "false")
        XCTAssertEqual(params["active"], "true")
        XCTAssertEqual(params["closed"], "false")
    }

    func test_endingSoon_hasCorrectSortParams() {
        let params = GammaEventQuery.params(offset: 0, tagID: nil, sort: .endingSoon, status: .active)
        XCTAssertEqual(params["order"], "endDate")
        XCTAssertEqual(params["ascending"], "true")
    }

    func test_statusAll_omitsActiveAndClosedKeys() {
        let params = GammaEventQuery.params(offset: 0, tagID: nil, sort: .volume24h, status: .all)
        XCTAssertNil(params["active"])
        XCTAssertNil(params["closed"])
    }

    func test_tagIDNil_omitsTagIDKey() {
        let params = GammaEventQuery.params(offset: 0, tagID: nil, sort: .volume24h, status: .active)
        XCTAssertNil(params["tag_id"])
    }

    func test_tagID_includedWhenProvided() {
        let params = GammaEventQuery.params(offset: 0, tagID: "5", sort: .volume24h, status: .active)
        XCTAssertEqual(params["tag_id"], "5")
    }
}
