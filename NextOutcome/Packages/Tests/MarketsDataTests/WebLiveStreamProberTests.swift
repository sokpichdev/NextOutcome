import XCTest
@testable import MarketsData
import MarketsDomain

final class WebLiveStreamProberTests: XCTestCase {
    func test_isLive_markers() {
        XCTAssertTrue(WebLiveStreamProber.isLive(html: #"<script type="application/ld+json">{"@type":"VideoObject","publication":[{"isLiveBroadcast":true}]}</script>"#))
        XCTAssertTrue(WebLiveStreamProber.isLive(html: #"{"videoDetails":{"isLive":true}}"#))
        XCTAssertFalse(WebLiveStreamProber.isLive(html: #"<html><body>offline channel page</body></html>"#))
        XCTAssertFalse(WebLiveStreamProber.isLive(html: #"{"videoDetails":{"isLive":false}}"#))
    }

    func test_youTubeVideoID_fromPlayerConfig() {
        let html = #"..."videoId":"nY8WLF8k2qE","title":"VCL Korea"..."#
        let url = URL(string: "https://www.youtube.com/@ValorantEsportsKR/live")!
        XCTAssertEqual(WebLiveStreamProber.youTubeVideoID(html: html, url: url), "nY8WLF8k2qE")
    }

    func test_youTubeVideoID_fallsBackToWatchURL() {
        let url = URL(string: "https://www.youtube.com/watch?v=abc123XYZ")!
        XCTAssertEqual(WebLiveStreamProber.youTubeVideoID(html: "no config here", url: url), "abc123XYZ")
    }

    func test_twitchChannel_parsing() {
        XCTAssertEqual(WebLiveStreamProber.twitchChannel(from: URL(string: "https://www.twitch.tv/ewc")!), "ewc")
        XCTAssertNil(WebLiveStreamProber.twitchChannel(from: URL(string: "https://www.twitch.tv")!))
    }

    func test_liveStream_unknownHostReturnsNil() async {
        let prober = WebLiveStreamProber()
        let result = await prober.liveStream(for: "https://hltv.org")
        XCTAssertNil(result)
    }
}
