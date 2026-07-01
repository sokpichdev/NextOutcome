//
//  PortfolioRepository.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import Foundation
import SharedDomain

/// Watch-only reads from the Data API. No signing, no custody.
public protocol PortfolioRepository: Sendable {
    func positions(address: String) async throws -> [Position]
    func value(address: String) async throws -> Decimal
    func activity(address: String, cursor: String?) async throws -> Page<Activity>
    func closedPositions(address: String) async throws -> [ClosedPosition]
    func leaderboard(metric: LeaderboardMetric, window: LeaderboardWindow) async throws -> [LeaderboardEntry]
}
