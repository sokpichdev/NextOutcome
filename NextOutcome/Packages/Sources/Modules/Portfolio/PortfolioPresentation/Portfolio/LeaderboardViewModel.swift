//
//  LeaderboardViewModel.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import Foundation
import PortfolioDomain

/// Drives the leaderboard screen: loads ranked traders and reloads whenever the user
/// changes the metric or time window.
@MainActor
@Observable
public final class LeaderboardViewModel {
    /// What the leaderboard is currently showing.
    public enum State {
        /// Loading entries.
        case loading
        /// Loaded ranked entries.
        case loaded([LeaderboardEntry])
        /// No entries for the selection.
        case empty
        /// The load failed.
        /// - Parameter String: A user-facing error message.
        case failed(String)
    }

    /// The current view state.
    public private(set) var state: State = .loading
    /// The ranking metric; changing it reloads.
    public var metric: LeaderboardMetric = .volume {
        didSet { Task { await load() } }
    }
    /// The time window; changing it reloads.
    public var window: LeaderboardWindow = .week {
        didSet { Task { await load() } }
    }

    /// Use case that fetches leaderboard entries.
    private let fetchLeaderboard: FetchLeaderboardUseCase

    /// Creates the view model.
    /// - Parameter fetchLeaderboard: Loads ranked entries.
    public init(fetchLeaderboard: FetchLeaderboardUseCase) {
        self.fetchLeaderboard = fetchLeaderboard
    }

    /// Loads the leaderboard for the current metric and window.
    public func load() async {
        state = .loading
        do {
            let entries = try await fetchLeaderboard.execute(metric: metric, window: window)
            state = entries.isEmpty ? .empty : .loaded(entries)
        } catch {
            state = .failed("Couldn't load the leaderboard.")
        }
    }
}
