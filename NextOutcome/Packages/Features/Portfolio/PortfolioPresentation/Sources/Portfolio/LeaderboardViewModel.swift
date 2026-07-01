//
//  LeaderboardViewModel.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import Foundation
import PortfolioDomain

@MainActor
@Observable
public final class LeaderboardViewModel {
    public enum State {
        case loading
        case loaded([LeaderboardEntry])
        case empty
        case failed(String)
    }

    public private(set) var state: State = .loading
    public var metric: LeaderboardMetric = .volume {
        didSet { Task { await load() } }
    }
    public var window: LeaderboardWindow = .week {
        didSet { Task { await load() } }
    }

    private let fetchLeaderboard: FetchLeaderboardUseCase

    public init(fetchLeaderboard: FetchLeaderboardUseCase) {
        self.fetchLeaderboard = fetchLeaderboard
    }

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
