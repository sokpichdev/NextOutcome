//
//  PoliticsShots.swift
//  NextOutcomeUITests
//
//  Politics hub.
//

import XCTest

final class PoliticsShots: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func test_politicsHub() {
        let app = launchForScreenshots(preselecting: "politics", tagID: PoliticsTag.id)
        settle(app, timeout: UIWait.firstLoad)
        capture("politics_hub", of: app)
    }
}
