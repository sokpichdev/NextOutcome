//
//  FetchServerTimeUseCase.swift
//  NextOutcome
//

import Foundation

/// Fetches the authoritative server time once, so the countdown can anchor to it and
/// tick forward using a local monotonic offset instead of refetching every second.
public struct FetchServerTimeUseCase: Sendable {
    /// The data source that provides authoritative server time.
    private let repository: OrderbookRepository

    /// Creates the use case.
    /// - Parameter repository: The order book repository to fetch from.
    public init(repository: OrderbookRepository) {
        self.repository = repository
    }

    /// Fetches the current server time.
    /// - Returns: The server's clock as a `Date`.
    /// - Throws: A networking error if the fetch fails.
    public func execute() async throws -> Date {
        try await repository.serverTime()
    }
}

/// Polls recent executed trades for the live ticker.
public struct FetchRecentTradesUseCase: Sendable {
    /// The data source that provides recent trades.
    private let repository: OrderbookRepository

    /// Creates the use case.
    /// - Parameter repository: The order book repository to fetch from.
    public init(repository: OrderbookRepository) {
        self.repository = repository
    }

    /// Fetches the most recent trades for an event.
    /// - Parameters:
    ///   - eventID: The event to fetch trades for.
    ///   - limit: The maximum number of trades to return. Defaults to 10.
    /// - Returns: Recent trades, newest first.
    /// - Throws: A networking error if the fetch fails.
    public func execute(eventID: String, limit: Int = 10) async throws -> [RecentTrade] {
        try await repository.recentTrades(eventID: eventID, limit: limit)
    }
}
