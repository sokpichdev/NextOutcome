//
//  EsportsLeaderboardViewModel.swift
//  NextOutcome
//
//  Created by Sok Pich on 14/07/2026.
//

import Foundation
import PortfolioDomain

/// Drives the Esports hub's Leaderboard tab: the esports-scoped `/v1/leaderboard`
/// rankings with a period dropdown and Profit/Volume sort, reloading on either change.
@MainActor
@Observable
public final class EsportsLeaderboardViewModel {
    /// What the leaderboard is currently showing.
    public enum State {
        case loading
        case loaded([LeaderboardEntry])
        case empty
        case failed(String)
    }

    /// The current view state.
    public private(set) var state: State = .loading
    /// The ranking metric; changing it reloads. Defaults to profit, matching web.
    public var metric: LeaderboardMetric = .profit {
        didSet { guard metric != oldValue else { return }; Task { await load() } }
    }
    /// The time window; changing it reloads. Defaults to monthly, matching web.
    public var window: LeaderboardWindow = .month {
        didSet { guard window != oldValue else { return }; Task { await load() } }
    }

    /// Whether the first load has run (so the view can lazy-load on first appearance).
    private var hasLoaded = false

    /// Use case that fetches leaderboard entries.
    private let fetchLeaderboard: FetchLeaderboardUseCase

    /// Creates the view model.
    /// - Parameter fetchLeaderboard: Loads ranked entries.
    public init(fetchLeaderboard: FetchLeaderboardUseCase) {
        self.fetchLeaderboard = fetchLeaderboard
    }

    /// Loads on first appearance only.
    public func loadIfNeeded() async {
        guard !hasLoaded else { return }
        await load()
    }

    /// Loads the esports leaderboard for the current metric and window.
    public func load() async {
        state = .loading
        do {
            let entries = try await fetchLeaderboard.execute(
                metric: metric, window: window, category: "esports", limit: 25
            )
            hasLoaded = true
            state = entries.isEmpty ? .empty : .loaded(entries)
        } catch {
            state = .failed("Couldn't load the leaderboard.")
        }
    }
}
