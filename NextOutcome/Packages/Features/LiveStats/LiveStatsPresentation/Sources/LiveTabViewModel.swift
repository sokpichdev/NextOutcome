//
//  LiveTabViewModel.swift
//  NextOutcome
//
//  Created by Sok Pich on 03/07/2026.
//

import Foundation
import Observation
import LiveStatsDomain

@Observable
@MainActor
public final class LiveTabViewModel {
    public enum State: Sendable, Equatable {
        case loading
        case live(MatchState)
        case failed(String)
    }

    public private(set) var state: State = .loading
    /// Connection lifecycle for the "reconnecting" pill on the hero. Starts reconnecting
    /// (nothing received yet), flips to `.live` once the first snapshot arrives.
    public private(set) var connection: MatchConnection = .reconnecting

    private let gameID: String
    private let streamer: SportsStateStreaming

    public init(gameID: String, streamer: SportsStateStreaming) {
        self.gameID = gameID
        self.streamer = streamer
    }

    /// The latest match snapshot, if any has arrived.
    public var match: MatchState? {
        if case let .live(m) = state { return m }
        return nil
    }

    /// Consumes the stream until cancelled. Drive this from the view's `.task` so it inherits
    /// the view lifecycle (auto-cancel on disappear) — no manual teardown needed.
    public func observe() async {
        state = .loading
        connection = .reconnecting
        do {
            for try await snapshot in streamer.states(gameID: gameID) {
                connection = .live
                state = .live(snapshot)
            }
        } catch is CancellationError {
            // Consumer went away; leave state as-is.
        } catch {
            connection = .reconnecting
            state = .failed("Couldn't load live stats.")
        }
    }

    /// Spawns `observe()` unstructured. Used by tests and the retry button; the view's
    /// `.task` drives `observe()` directly for its main subscription.
    public func start() {
        Task { await observe() }
    }

    public func retry() { start() }

    public func availability(of section: LiveSection) -> SectionAvailability {
        section.availability(in: match)
    }
}
