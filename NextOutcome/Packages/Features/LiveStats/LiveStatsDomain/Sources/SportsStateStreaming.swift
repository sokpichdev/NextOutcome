//
//  SportsStateStreaming.swift
//  NextOutcome
//
//  Created by Sok Pich on 03/07/2026.
//

import Foundation

/// Streams live `MatchState` snapshots for a single game. Implementations own their own
/// reconnect/backoff; the stream terminates only on cancellation or an unrecoverable error.
public protocol SportsStateStreaming: Sendable {
    /// Opens a stream of live match snapshots for one game.
    /// - Parameter gameID: The feed's identifier for the game to follow.
    /// - Returns: An async stream that yields a new `MatchState` each time the feed
    ///   pushes an update, and finishes on cancellation or an unrecoverable error.
    func states(gameID: String) -> AsyncThrowingStream<MatchState, Error>
}
