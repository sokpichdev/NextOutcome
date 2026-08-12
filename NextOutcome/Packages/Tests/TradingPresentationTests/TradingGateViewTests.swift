import XCTest
import TradingDomain
@testable import TradingPresentation

final class TradingGateViewTests: XCTestCase {
    func test_blocked_namesTheRegionWhenKnown() {
        XCTAssertEqual(TradingGateView.message(for: .blocked(region: "US")),
                       "Trading isn't available in US.")
    }

    func test_blocked_fallsBackWhenRegionIsMissing() {
        XCTAssertEqual(TradingGateView.message(for: .blocked(region: nil)),
                       "Trading isn't available in your region.")
        // An empty string is the same thing as absent, and reads as " in ." if not caught.
        XCTAssertEqual(TradingGateView.message(for: .blocked(region: "")),
                       "Trading isn't available in your region.")
    }

    /// Close-only users can still exit what they hold — the copy must not tell them
    /// trading is unavailable.
    func test_closeOnly_doesNotClaimTradingIsUnavailable() {
        let message = TradingGateView.message(for: .closeOnly(region: "FR"))
        XCTAssertEqual(message, "You can close existing positions in FR, but not open new ones.")
        XCTAssertFalse(message.contains("isn't available"))
        XCTAssertEqual(TradingGateView.title(for: .closeOnly(region: "FR")), "Closing positions only")
    }

    func test_deniedStatesGetDistinctTitlesAndIcons() {
        XCTAssertNotEqual(TradingGateView.title(for: .blocked(region: nil)),
                          TradingGateView.title(for: .closeOnly(region: nil)))
        XCTAssertNotEqual(TradingGateView.icon(for: .blocked(region: nil)),
                          TradingGateView.icon(for: .closeOnly(region: nil)))
    }
}
