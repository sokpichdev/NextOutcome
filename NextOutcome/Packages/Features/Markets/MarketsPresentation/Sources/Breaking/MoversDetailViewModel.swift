//
//  MoversDetailViewModel.swift
//  NextOutcome
//
//  Created by Sok Pich on 05/07/2026.
//

import Foundation
import MarketsDomain
import OrderbookPresentation

/// Drives the bespoke movers detail screen. A mover is a single market, but the detail charts
/// its *sibling* outcomes (the other markets of the same event), so this fetches the full
/// parent event by slug and hands it to an `EventChartViewModel` for the multi-series chart.
@MainActor
@Observable
public final class MoversDetailViewModel {
    /// The mover that opened this screen — supplies the header (question, chance, delta).
    public let mover: Mover
    /// The loaded parent event, once fetched. Its markets drive the chart and the trade row.
    public private(set) var event: Event?
    /// The multi-series chart view model, created once the event is loaded.
    public private(set) var chart: EventChartViewModel?
    /// Whether the event fetch is in flight.
    public private(set) var isLoading = false
    /// A user-facing error message when the event fetch fails, else `nil`.
    public private(set) var errorMessage: String?

    /// Fetches the full parent event by slug.
    private let fetchEvent: @Sendable (String) async throws -> Event
    /// Supplies price-history data to the chart.
    private let provider: PriceHistoryProvider

    /// Creates the view model.
    /// - Parameters:
    ///   - mover: The tapped mover.
    ///   - fetchEvent: Fetches the parent event by slug.
    ///   - provider: The price-history data source for the chart.
    public init(
        mover: Mover,
        fetchEvent: @escaping @Sendable (String) async throws -> Event,
        provider: PriceHistoryProvider
    ) {
        self.mover = mover
        self.fetchEvent = fetchEvent
        self.provider = provider
    }

    /// The market this mover refers to (matched by id within the event), falling back to the
    /// event's first market. Drives the Buy Yes/No trade row.
    public var primaryMarket: Market? {
        guard let event else { return nil }
        return event.markets.first { $0.id == mover.id } ?? event.markets.first
    }

    /// The category breadcrumb shown under the back button (e.g. "Tech · AI"), built from the
    /// event's first couple of tags. Empty when the event isn't loaded or has no tags.
    public var categoryBreadcrumb: String {
        (event?.tags.prefix(2).map(\.label) ?? []).joined(separator: " · ")
    }

    /// Loads the parent event and builds/loads the chart. Idempotent: skips if already loaded.
    public func load() async {
        guard event == nil, !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let event = try await fetchEvent(mover.eventSlug)
            self.event = event
            let chart = EventChartViewModel(event: event, provider: provider)
            self.chart = chart
            await chart.load()
        } catch {
            errorMessage = "Couldn't load this market. Check your connection and try again."
        }
    }
}
