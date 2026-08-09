//
//  EsportsStreamEmbeddableTests.swift
//  NextOutcome
//

import XCTest
@testable import MarketsDomain

final class EsportsStreamEmbeddableTests: XCTestCase {
    func test_youTubeWatchURL_carriesItsOwnVideoID() {
        // The MLBB case: every Mobile Legends event points at a YouTube watch URL, and the
        // id is right there in the query — no page fetch can tell us anything we don't have.
        XCTAssertEqual(
            EsportsStream.embeddable(from: "https://www.youtube.com/watch?v=zbEa-ffJs0w"),
            .youtube(videoID: "zbEa-ffJs0w")
        )
    }

    func test_youTubeShortAndEmbedURLs() {
        XCTAssertEqual(EsportsStream.embeddable(from: "https://youtu.be/kKf3BgqrZvk"),
                       .youtube(videoID: "kKf3BgqrZvk"))
        XCTAssertEqual(EsportsStream.embeddable(from: "https://www.youtube.com/embed/kKf3BgqrZvk"),
                       .youtube(videoID: "kKf3BgqrZvk"))
    }

    func test_twitchChannelURL() {
        XCTAssertEqual(EsportsStream.embeddable(from: "https://www.twitch.tv/eslcs"),
                       .twitch(channel: "eslcs"))
    }

    func test_urlsThatNameNoBroadcast() {
        // A channel's Streams/Live tab names a channel, not a video — only a fetch can say
        // which broadcast is playing, so these must stay `nil` and fall through to the probe.
        XCTAssertNil(EsportsStream.embeddable(from: "https://www.youtube.com/@MLBBeSports/streams"))
        XCTAssertNil(EsportsStream.embeddable(from: "https://www.youtube.com/@ValorantEsportsKR/live"))
        // Not a streaming site at all.
        XCTAssertNil(EsportsStream.embeddable(from: "https://www.hltv.org/"))
        XCTAssertNil(EsportsStream.embeddable(from: "https://www.twitch.tv"))
        XCTAssertNil(EsportsStream.embeddable(from: ""))
        XCTAssertNil(EsportsStream.embeddable(from: "not a url at all"))
    }
}
