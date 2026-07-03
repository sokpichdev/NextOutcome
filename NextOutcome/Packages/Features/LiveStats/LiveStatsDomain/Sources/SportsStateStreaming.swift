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
    func states(gameID: String) -> AsyncThrowingStream<MatchState, Error>
}
