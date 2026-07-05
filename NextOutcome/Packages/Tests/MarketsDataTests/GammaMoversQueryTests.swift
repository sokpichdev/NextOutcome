import XCTest
@testable import MarketsData

final class GammaMoversQueryTests: XCTestCase {
    func test_ascending_true_meansBiggestLosers() {
        let params = GammaMoversQuery.params(tagID: nil, ascending: true)
        XCTAssertEqual(params["order"], "oneDayPriceChange")
        XCTAssertEqual(params["ascending"], "true")
    }

    func test_ascending_false_meansBiggestGainers() {
        let params = GammaMoversQuery.params(tagID: nil, ascending: false)
        XCTAssertEqual(params["ascending"], "false")
    }

    func test_onlyActiveUnclosedMarkets() {
        let params = GammaMoversQuery.params(tagID: nil, ascending: true)
        XCTAssertEqual(params["active"], "true")
        XCTAssertEqual(params["closed"], "false")
    }

    func test_appliesVolumeFloor_toDropIlliquidNoise() {
        let params = GammaMoversQuery.params(tagID: nil, ascending: true)
        XCTAssertEqual(params["volume_num_min"], "10000")
    }

    func test_tagIDNil_omitsTagIDKey() {
        let params = GammaMoversQuery.params(tagID: nil, ascending: true)
        XCTAssertNil(params["tag_id"])
    }

    func test_tagID_includedWhenProvided() {
        let params = GammaMoversQuery.params(tagID: "1", ascending: true)
        XCTAssertEqual(params["tag_id"], "1")
    }
}
