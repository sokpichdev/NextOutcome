import XCTest
@testable import MarketsPresentation

final class LiveTabGateTests: XCTestCase {
    func testLiveShownDuringMatch() {
        XCTAssertTrue(LiveTabGate.showsLive(gameStartTime: .distantPast, hasTeams: true, isResolved: false, now: Date()))
    }

    func testHiddenBeforeKickoffOrWithoutTeams() {
        XCTAssertFalse(LiveTabGate.showsLive(gameStartTime: Date().addingTimeInterval(3600), hasTeams: true, isResolved: false, now: Date()))
        XCTAssertFalse(LiveTabGate.showsLive(gameStartTime: .distantPast, hasTeams: false, isResolved: false, now: Date()))
    }

    func testHiddenWhenNoStartTime() {
        XCTAssertFalse(LiveTabGate.showsLive(gameStartTime: nil, hasTeams: true, isResolved: false, now: Date()))
    }

    func testHiddenWhenResolved() {
        XCTAssertFalse(LiveTabGate.showsLive(gameStartTime: .distantPast, hasTeams: true, isResolved: true, now: Date()))
    }
}
