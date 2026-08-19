import XCTest
@testable import DesignSystem

/// `DepthLevel`'s identity is the thing that stops a live order book from rebuilding
/// every row several times a second, so it gets its own test.
final class DepthLevelTests: XCTestCase {
    func testIdentityIsStableAcrossRebuildsOfTheSameLevel() {
        let first = DepthLevel(price: "62.0¢", size: "1.2K", fraction: 0.4)
        // Same price, new size/fraction — what a socket tick produces.
        let second = DepthLevel(price: "62.0¢", size: "1.4K", fraction: 0.5)

        XCTAssertEqual(first.id, second.id)
    }

    func testDifferentPricesGetDifferentIdentities() {
        let bid = DepthLevel(price: "62.0¢", size: "1.2K", fraction: 0.4)
        let next = DepthLevel(price: "61.9¢", size: "1.2K", fraction: 0.4)

        XCTAssertNotEqual(bid.id, next.id)
    }

    func testExplicitIdentityDisambiguatesLevelsThatFormatIdentically() {
        let lower = DepthLevel(id: "0.6201", price: "62.0¢", size: "1.2K", fraction: 0.4)
        let upper = DepthLevel(id: "0.6204", price: "62.0¢", size: "0.9K", fraction: 0.3)

        XCTAssertNotEqual(lower.id, upper.id)
    }
}
