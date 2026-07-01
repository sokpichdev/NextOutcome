import XCTest
@testable import TradingDomain

final class TradeLifecycleReducerTests: XCTestCase {
    func test_forwardTransitions() {
        XCTAssertEqual(TradeLifecycleReducer.reduce(.matched, .mined), .mined)
        XCTAssertEqual(TradeLifecycleReducer.reduce(.mined, .confirmed), .confirmed)
        XCTAssertEqual(TradeLifecycleReducer.reduce(.retrying, .mined), .mined)
    }

    func test_terminalIsSticky() {
        XCTAssertEqual(TradeLifecycleReducer.reduce(.confirmed, .matched), .confirmed)
        XCTAssertEqual(TradeLifecycleReducer.reduce(.failed, .mined), .failed)
    }

    func test_illegalTransitionsIgnored() {
        // can't go backwards or skip
        XCTAssertEqual(TradeLifecycleReducer.reduce(.mined, .matched), .mined)
        XCTAssertEqual(TradeLifecycleReducer.reduce(.matched, .confirmed), .matched)
    }
}

final class OrderTicketTests: XCTestCase {
    func test_validate_rejectsOutOfRangePrice() {
        let ticket = OrderTicket(tokenID: "t", side: .buy, price: 1.5, size: 10)
        XCTAssertEqual(ticket.validate(tickSize: 0.01, minOrderSize: 5),
                       .invalid("Price must be between 0 and 1."))
    }

    func test_validate_rejectsBelowMinSize() {
        let ticket = OrderTicket(tokenID: "t", side: .buy, price: 0.5, size: 1)
        XCTAssertEqual(ticket.validate(tickSize: 0.01, minOrderSize: 5),
                       .invalid("Below minimum order size."))
    }

    func test_validate_acceptsOnTickPrice() {
        let ticket = OrderTicket(tokenID: "t", side: .buy, price: 0.55, size: 10)
        XCTAssertEqual(ticket.validate(tickSize: 0.01, minOrderSize: 5), .valid)
    }
}
