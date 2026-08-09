//
//  EsportsStream.swift
//  NextOutcome
//
//  Created by Sok Pich on 15/07/2026.
//

import Foundation

/// A confirmed-live broadcast for an esports match, resolved from the event's
/// `resolutionSource` URL. Only produced when the match is known to be on air —
/// otherwise the UI shows artwork instead of an offline player.
public enum EsportsStream: Equatable, Sendable {
    /// A live Twitch broadcast on the given channel.
    case twitch(channel: String)
    /// A live YouTube broadcast with the given video id.
    case youtube(videoID: String)

    /// The broadcast a `resolutionSource` names outright, with no network round trip —
    /// or `nil` when the URL identifies a channel rather than a specific broadcast.
    ///
    /// Callers must already know the match is live: this says *what* to embed, never
    /// *whether* to. `LiveStreamProbing` remains the answer to that question for every URL
    /// this can't resolve.
    ///
    /// It exists because probing is impossible for YouTube in practice. Mobile Legends
    /// points every match at YouTube, which answers our keyless page fetch with a bot check
    /// (302 → `google.com/sorry`) or a 404 — so the probe returns "not live" for a match
    /// that plainly is, and the hero falls back to artwork while polymarket.com plays the
    /// stream. Where the URL carries the video id there is nothing for a fetch to add.
    public static func embeddable(from resolutionSource: String) -> EsportsStream? {
        guard let components = URLComponents(string: resolutionSource),
              let host = components.host else { return nil }
        // Non-empty path components, e.g. ["watch"] or ["embed", "<id>"].
        let path = components.path.split(separator: "/").map(String.init)

        if host.contains("twitch.tv") {
            // Any twitch.tv/<channel> is embeddable; the channel is the whole address.
            guard let channel = path.first, !channel.isEmpty else { return nil }
            return .twitch(channel: channel)
        }
        if host.contains("youtu.be") {
            guard let id = path.first, !id.isEmpty else { return nil }
            return .youtube(videoID: id)
        }
        if host.contains("youtube.com") {
            if let id = components.queryItems?.first(where: { $0.name == "v" })?.value, !id.isEmpty {
                return .youtube(videoID: id)
            }
            if path.first == "embed", path.count > 1 {
                return .youtube(videoID: path[1])
            }
            // `/@handle/live` and `/@handle/streams` name a channel, not a broadcast —
            // only a fetch can say which video is playing.
            return nil
        }
        return nil
    }
}

/// Probes whether the broadcast behind a `resolutionSource` URL is currently live.
public protocol LiveStreamProbing: Sendable {
    /// Resolves a resolution-source URL to a live stream, or `nil` when the URL isn't a
    /// known streaming site or the channel is offline. Best-effort: network failures
    /// also return `nil`.
    func liveStream(for resolutionSource: String) async -> EsportsStream?
}
