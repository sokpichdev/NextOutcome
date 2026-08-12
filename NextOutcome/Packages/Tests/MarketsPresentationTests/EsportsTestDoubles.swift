//
//  EsportsTestDoubles.swift
//  NextOutcome
//
//  Doubles shared by the Esports hub and match-detail test suites.
//

import Foundation
import MarketsDomain
import LiveStatsDomain

/// Hand-driven sports socket: tests push `MatchState` snapshots into per-game streams.
final class FakeStreamer: SportsStateStreaming, @unchecked Sendable {
    private var continuations: [String: AsyncThrowingStream<MatchState, Error>.Continuation] = [:]
    private(set) var cancelledGameIDs: Set<String> = []

    func states(gameID: String) -> AsyncThrowingStream<MatchState, Error> {
        AsyncThrowingStream { continuation in
            continuations[gameID] = continuation
            continuation.onTermination = { [weak self] _ in
                self?.cancelledGameIDs.insert(gameID)
            }
        }
    }

    func push(gameID: String, state: MatchState) {
        continuations[gameID]?.yield(state)
    }

    func hasSubscriber(gameID: String) -> Bool {
        continuations[gameID] != nil
    }

    /// Every game id a subscription has been opened for, so a test can assert *which* id
    /// the caller subscribed with.
    var subscribedGameIDs: Set<String> { Set(continuations.keys) }
}

/// Resolves canned stream URLs to live streams.
struct FakeProber: LiveStreamProbing {
    let streams: [String: EsportsStream]
    func liveStream(for resolutionSource: String) async -> EsportsStream? {
        streams[resolutionSource]
    }
}
