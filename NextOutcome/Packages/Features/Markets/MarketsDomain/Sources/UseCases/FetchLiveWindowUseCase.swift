//
//  FetchLiveWindowUseCase.swift
//  NextOutcome
//

import Foundation

/// Loads the currently-open window of a clock-gridded recurring series (e.g. BTC Up/Down 5m).
public struct FetchLiveWindowUseCase: Sendable {
    /// The market repository backing this use case.
    private let repository: MarketRepository

    /// Creates the use case.
    /// - Parameter repository: The market repository to fetch from.
    public init(repository: MarketRepository) {
        self.repository = repository
    }

    /// Fetches the window live at `now`, or `nil` when there isn't one.
    ///
    /// Returns `nil` rather than throwing on *any* failure. A missing window is a normal
    /// outcome, not an error: the series occasionally skips a slot, and a window that has
    /// just rolled over may not be queryable for a moment. This card is an enhancement
    /// pinned above the hub — it must never be able to fail the screen behind it.
    ///
    /// The returned event is checked for liveness rather than trusted: a window whose markets
    /// have all resolved is dropped, so a stale grid slot renders nothing instead of a card
    /// showing a settled 99/1 price as though it were tradeable.
    /// - Parameters:
    ///   - series: The series to resolve.
    ///   - now: The instant to resolve against. Injected for tests.
    /// - Returns: The live event, or `nil`.
    public func execute(series: ClockGriddedSeries = .bitcoinUpDown5m, now: Date = Date()) async -> Event? {
        guard let event = try? await repository.fetchEvent(slug: series.slug(at: now)) else { return nil }
        guard !event.isEnded, !event.isResolved, !event.markets.isEmpty else { return nil }
        return event
    }

    /// Returns an instance whose `execute` always returns `nil`. Use in unit tests.
    #if DEBUG
    public static let stub = FetchLiveWindowUseCase(repository: StubMarketRepository())
    #endif
}
