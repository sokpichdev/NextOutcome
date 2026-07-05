//
//  LiveTabViewModel.swift
//  NextOutcome
//
//  Created by Sok Pich on 03/07/2026.
//

import Foundation
import Observation
import LiveStatsDomain

/// Drives the Live sub-tab: subscribes to the sports feed for one game and exposes the
/// latest snapshot plus connection status for the view to render.
///
/// `@Observable` so SwiftUI re-renders when `state`/`connection` change, and `@MainActor`
/// so all UI-facing mutation happens on the main thread.
@Observable
@MainActor
public final class LiveTabViewModel {
    /// What the Live tab is currently showing.
    public enum State: Sendable, Equatable {
        /// Waiting for the first snapshot.
        case loading
        /// Showing a live snapshot.
        /// - Parameter MatchState: The most recent match state received.
        case live(MatchState)
        /// The stream failed.
        /// - Parameter String: A user-facing error message.
        case failed(String)
    }

    /// The current view state. Read-only to the outside; only `observe()` mutates it.
    public private(set) var state: State = .loading
    /// Connection lifecycle for the "reconnecting" pill on the hero. Starts reconnecting
    /// (nothing received yet), flips to `.live` once the first snapshot arrives.
    public private(set) var connection: MatchConnection = .reconnecting

    /// The game this view model is following.
    private let gameID: String
    /// The stream source providing live snapshots.
    private let streamer: SportsStateStreaming

    /// Creates the view model.
    /// - Parameters:
    ///   - gameID: The game to follow.
    ///   - streamer: The live-stats stream source (injected from the environment).
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

    /// Re-subscribes after a failure. Wired to the error state's "Try again" button.
    public func retry() { start() }

    /// Reports whether a given Live-tab section has data to show for the current snapshot,
    /// so the view can hide or placeholder sections the feed didn't provide.
    /// - Parameter section: The section to check.
    /// - Returns: Whether that section is available given the latest `match`.
    public func availability(of section: LiveSection) -> SectionAvailability {
        section.availability(in: match)
    }
}
