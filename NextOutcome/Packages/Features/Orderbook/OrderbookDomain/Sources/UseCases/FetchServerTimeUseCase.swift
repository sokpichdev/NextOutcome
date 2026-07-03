//
//  FetchServerTimeUseCase.swift
//  NextOutcome
//

import Foundation

/// Fetches the authoritative server time once, so the countdown can anchor to it and
/// tick forward using a local monotonic offset instead of refetching every second.
public struct FetchServerTimeUseCase: Sendable {
    private let repository: OrderbookRepository

    public init(repository: OrderbookRepository) {
        self.repository = repository
    }

    public func execute() async throws -> Date {
        try await repository.serverTime()
    }
}

/// Polls recent executed trades for the live ticker.
public struct FetchRecentTradesUseCase: Sendable {
    private let repository: OrderbookRepository

    public init(repository: OrderbookRepository) {
        self.repository = repository
    }

    public func execute(eventID: String, limit: Int = 10) async throws -> [RecentTrade] {
        try await repository.recentTrades(eventID: eventID, limit: limit)
    }
}
