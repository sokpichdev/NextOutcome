//
//  FetchAllEventsUseCase.swift
//  NextOutcome
//
//  Created by Sok Pich on 05/07/2026.
//

import Foundation

/// Loads all events under a Gamma tag (e.g. the Politics hub's "midterms" or "referendums"
/// tags), unpaginated.
public struct FetchAllEventsUseCase: Sendable {
    /// The market repository backing this use case.
    private let repository: MarketRepository
    /// Injected clock, so the abandoned-event filter is testable without waiting.
    private let now: @Sendable () -> Date

    /// Creates the use case.
    /// - Parameters:
    ///   - repository: The market repository to fetch from.
    ///   - now: Supplies the current time; override in tests.
    public init(repository: MarketRepository, now: @escaping @Sendable () -> Date = { Date() }) {
        self.repository = repository
        self.now = now
    }

    /// Fetches a tag's events, dropping ones Gamma has abandoned.
    ///
    /// The filter applies **only to `.active`**, where the caller has asked for events that
    /// are still running and a long-expired row is simply wrong. `.resolved` and `.all` are
    /// left untouched: past-dated events are exactly what those ask for — the team-profile
    /// screen builds a match history from `.all` and would lose every completed game.
    ///
    /// This is a client-side filter because there is no server-side one: Gamma silently
    /// ignores `end_date_min` (see `docs/polymarket-data-freshness.md` §3.5).
    /// - Parameters:
    ///   - tagID: The tag id.
    ///   - status: Which events to include. Defaults to active only.
    /// - Returns: The tag's events.
    public func execute(tagID: String, status: EventStatus = .active) async throws -> [Event] {
        let events = try await repository.fetchAllEvents(tagID: tagID, status: status)
        guard status == .active else { return events }
        let asOf = now()
        return events.filter { !$0.isAbandoned(asOf: asOf) }
    }

    /// Returns an instance whose `execute` always returns no events. Use in unit tests.
    #if DEBUG
    public static let stub = FetchAllEventsUseCase(repository: StubMarketRepository())
    #endif
}
