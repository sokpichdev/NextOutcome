//
//  WebLiveStreamProber.swift
//  NextOutcome
//
//  Created by Sok Pich on 15/07/2026.
//

import Foundation
import MarketsDomain

/// Keyless live-status probe: fetches the public Twitch/YouTube channel page and looks
/// for the server-rendered live markers, avoiding any API registration.
///
/// - Twitch renders an `isLiveBroadcast` LD+JSON block only while the channel is on air.
/// - YouTube's `/live` (and watch) pages carry the current/upcoming `videoId` plus an
///   `isLiveBroadcast`/`"isLive":true` marker only during a live broadcast.
///
/// Trade-off vs. the official Helix/Data APIs: no client id or secret to manage, at the
/// cost of relying on page markup that could change. Both parsers are pure and
/// fixture-tested so a breakage is caught by tests, and every failure degrades to
/// "not live" (artwork instead of a player) rather than an error.
public struct WebLiveStreamProber: LiveStreamProbing {
    /// The HTTP session used for page fetches.
    private let session: URLSession

    /// Creates the prober.
    /// - Parameter session: The URL session to fetch with. Defaults to an ephemeral
    ///   session with short timeouts, so a slow page never stalls the hub's poll.
    public init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.ephemeral
            config.timeoutIntervalForRequest = 8
            self.session = URLSession(configuration: config)
        }
    }

    public func liveStream(for resolutionSource: String) async -> EsportsStream? {
        guard let url = URL(string: resolutionSource), let host = url.host else { return nil }
        if host.contains("twitch.tv") {
            guard let channel = Self.twitchChannel(from: url),
                  let html = await fetch(url),
                  Self.isLive(html: html) else { return nil }
            return .twitch(channel: channel)
        }
        if host.contains("youtube.com") || host.contains("youtu.be") {
            guard let html = await fetch(url),
                  Self.isLive(html: html),
                  let videoID = Self.youTubeVideoID(html: html, url: url) else { return nil }
            return .youtube(videoID: videoID)
        }
        return nil
    }

    /// Fetches a page's HTML with a browser user agent (both sites serve the marker-bearing
    /// server-rendered page to browsers). Returns `nil` on any failure.
    private func fetch(_ url: URL) async -> String? {
        var request = URLRequest(url: url)
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 26_0 like Mac OS X) AppleWebKit/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )
        guard let (data, response) = try? await session.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Pure parsers (fixture-tested)

    /// Both Twitch and YouTube server-render an `isLiveBroadcast` marker only while the
    /// broadcast is live; YouTube additionally emits `"isLive":true` in its player config.
    static func isLive(html: String) -> Bool {
        html.contains("isLiveBroadcast") || html.contains("\"isLive\":true")
    }

    /// The current broadcast's video id: preferring the canonical `watch?v=` URL, then the
    /// first player-config `"videoId":"…"`, then a `v=` query item on the request URL itself.
    static func youTubeVideoID(html: String, url: URL) -> String? {
        if let range = html.range(of: #""videoId":""#),
           let end = html[range.upperBound...].firstIndex(of: "\"") {
            let id = String(html[range.upperBound..<end])
            if !id.isEmpty { return id }
        }
        return URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == "v" }?.value
    }

    /// The channel name from a `twitch.tv/<channel>` URL.
    static func twitchChannel(from url: URL) -> String? {
        let channel = url.pathComponents.first { $0 != "/" }
        return (channel?.isEmpty == false) ? channel : nil
    }
}
