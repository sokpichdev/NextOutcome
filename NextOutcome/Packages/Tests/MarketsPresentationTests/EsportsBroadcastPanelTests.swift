//
//  EsportsBroadcastPanelTests.swift
//  NextOutcome
//

import XCTest
import Foundation
@testable import MarketsPresentation

final class EsportsBroadcastPanelTests: XCTestCase {

    private func label(_ urlString: String) -> String {
        EsportsBroadcastPanel.watchLabel(for: URL(string: urlString)!)
    }

    func test_namesTheHostItLinksTo() {
        XCTAssertEqual(label("https://www.twitch.tv/eslcs"), "Watch on Twitch")
        XCTAssertEqual(label("https://player.twitch.tv/?channel=eslcs"), "Watch on Twitch")
        XCTAssertEqual(label("https://www.youtube.com/watch?v=zbEa-ffJs0w"), "Watch on YouTube")
        XCTAssertEqual(label("https://youtu.be/zbEa-ffJs0w"), "Watch on YouTube")
        // The host we can't embed, and so the one most likely to be tapped.
        XCTAssertEqual(label("https://kick.com/eplcs_en"), "Watch on Kick")
    }

    func test_unknownHostsFallBackToAGenericLabel() {
        XCTAssertEqual(label("https://hltv.org/matches/123"), "Open broadcast")
        XCTAssertEqual(label("https://liquipedia.net/dota2"), "Open broadcast")
    }
}
