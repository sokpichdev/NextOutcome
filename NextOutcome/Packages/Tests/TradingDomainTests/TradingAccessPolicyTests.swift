import XCTest
@testable import TradingDomain

final class TradingAccessPolicyTests: XCTestCase {
    private func status(blocked: Bool = false, closeOnly: Bool = false,
                        region: String? = "US") -> GeoblockStatus {
        GeoblockStatus(blocked: blocked, closeOnly: closeOnly, region: region)
    }

    func test_clearStatus_allowsTrading() {
        XCTAssertEqual(TradingAccessPolicy.resolve(status: status()), .allowed)
    }

    func test_blocked_deniesWithRegion() {
        XCTAssertEqual(TradingAccessPolicy.resolve(status: status(blocked: true)),
                       .blocked(region: "US"))
    }

    func test_closeOnly_deniesSeparatelyFromBlocked() {
        XCTAssertEqual(TradingAccessPolicy.resolve(status: status(closeOnly: true)),
                       .closeOnly(region: "US"))
    }

    /// The endpoint can report both; blocked is the stricter reading, so it wins.
    func test_bothFlags_blockedWins() {
        XCTAssertEqual(TradingAccessPolicy.resolve(status: status(blocked: true, closeOnly: true)),
                       .blocked(region: "US"))
    }

    func test_missingRegion_stillDenies() {
        XCTAssertEqual(TradingAccessPolicy.resolve(status: status(blocked: true, region: nil)),
                       .blocked(region: nil))
    }

    func test_override_forcesAllowed() {
        XCTAssertEqual(TradingAccessPolicy.resolve(status: status(blocked: true), override: true),
                       .allowed)
        XCTAssertEqual(TradingAccessPolicy.resolve(status: status(closeOnly: true), override: true),
                       .allowed)
    }

    func test_canOpenPosition_onlyWhenAllowed() {
        XCTAssertTrue(TradingAccess.allowed.canOpenPosition)
        XCTAssertFalse(TradingAccess.blocked(region: "US").canOpenPosition)
        XCTAssertFalse(TradingAccess.closeOnly(region: "US").canOpenPosition)
    }
}
