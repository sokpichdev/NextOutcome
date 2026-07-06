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

    func test_seriesParams_active_boundsByClosedOnly() {
        let params = GammaEventQuery.seriesParams(seriesID: "11433", offset: 0, status: .active)
        XCTAssertEqual(params["series_id"], "11433")
        XCTAssertEqual(params["limit"], "100")
        XCTAssertEqual(params["offset"], "0")
        // A tournament series must keep in-play games visible, so only resolved
        // events are excluded (`active=true` would drop live games).
        XCTAssertEqual(params["closed"], "false")
        XCTAssertNil(params["active"])
    }

    func test_seriesParams_statusAll_omitsClosed() {
        let params = GammaEventQuery.seriesParams(seriesID: "11433", offset: 100, status: .all)
        XCTAssertEqual(params["offset"], "100")
        XCTAssertNil(params["closed"])
    }

    func test_tagParams_active_boundsByClosedOnly() {
        let params = GammaEventQuery.tagParams(tagID: "102289", offset: 0, status: .active)
        XCTAssertEqual(params["tag_id"], "102289")
        XCTAssertEqual(params["limit"], "100")
        XCTAssertEqual(params["offset"], "0")
        XCTAssertEqual(params["closed"], "false")
    }

    func test_tagParams_statusAll_omitsClosed() {
        let params = GammaEventQuery.tagParams(tagID: "102289", offset: 100, status: .all)
        XCTAssertEqual(params["offset"], "100")
        XCTAssertNil(params["closed"])
    }
}
