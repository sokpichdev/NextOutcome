//
//  EsportsStream.swift
//  NextOutcome
//
//  Created by Sok Pich on 15/07/2026.
//

/// A confirmed-live broadcast for an esports match, resolved from the event's
/// `resolutionSource` URL. Only produced when the channel is actually on air —
/// offline channels yield no stream, so the UI shows artwork instead of an
/// offline player.
public enum EsportsStream: Equatable, Sendable {
    /// A live Twitch broadcast on the given channel.
    case twitch(channel: String)
    /// A live YouTube broadcast with the given video id.
    case youtube(videoID: String)
}

/// Probes whether the broadcast behind a `resolutionSource` URL is currently live.
public protocol LiveStreamProbing: Sendable {
    /// Resolves a resolution-source URL to a live stream, or `nil` when the URL isn't a
    /// known streaming site or the channel is offline. Best-effort: network failures
    /// also return `nil`.
    func liveStream(for resolutionSource: String) async -> EsportsStream?
}
