//
//  MoversDetailViewModel.swift
//  NextOutcome
//
//  Created by Sok Pich on 05/07/2026.
//

import Foundation
import MarketsDomain
import OrderbookPresentation

/// Drives the bespoke movers detail screen. A mover is a single market, but the detail shows
/// its *sibling* outcomes (the other markets of the same event) — either as a multi-series
/// chart (mutually-exclusive candidates resolving on one date) or a scrollable list of
/// per-date rows (a "by \<date\>" cumulative ladder), per `EventLayoutClassifier`. Fetches the
/// full parent event by slug.
@MainActor
@Observable
public final class MoversDetailViewModel {
    /// The mover that opened this screen — supplies the header (question, chance, delta).
    public let mover: Mover
    /// The loaded parent event, once fetched. Its markets drive the chart/ladder and trade row.
    public private(set) var event: Event?
    /// The multi-series chart view model, built only when `layout == .chart`.
    public private(set) var chart: EventChartViewModel?
    /// The Comments/Top Holders/Positions/Activity social strip, built once the event loads.
    public private(set) var socialStrip: SocialStripViewModel?
    /// Whether the event fetch is in flight.
    public private(set) var isLoading = false
    /// A user-facing error message when the event fetch fails, else `nil`.
    public private(set) var errorMessage: String?

    /// Which layout the loaded event's markets call for. `.chart` before the event loads (so
    /// the loading placeholder renders as a chart-shaped skeleton, matching the common case).
    public var layout: EventLayout {
        guard let event else { return .chart }
        return EventLayoutClassifier.classify(event.markets)
    }

    /// The date-ladder rows when `layout == .dateLadder`: the event's unresolved markets
    /// (closed thresholds are old news once the release already happened), soonest deadline
    /// first. Empty for `.chart` events or before the event loads.
    public var dateLadderMarkets: [Market] {
        guard let event, layout == .dateLadder else { return [] }
        return event.markets
            .filter { !$0.isResolved }
            .sorted { ($0.endDate ?? .distantFuture) < ($1.endDate ?? .distantFuture) }
    }

    /// Fetches the full parent event by slug.
    private let fetchEvent: @Sendable (String) async throws -> Event
    /// Supplies price-history data to the chart.
    private let provider: PriceHistoryProvider
    /// Builds the social strip view model from an event id, condition id, and markets.
    private let makeSocialStrip: @MainActor (String, String?, [Market]) -> SocialStripViewModel

    /// Creates the view model.
    /// - Parameters:
    ///   - mover: The tapped mover.
    ///   - fetchEvent: Fetches the parent event by slug.
    ///   - provider: The price-history data source for the chart.
    ///   - makeSocialStrip: Builds the Comments/Top Holders/Positions/Activity social strip.
    public init(
        mover: Mover,
        fetchEvent: @escaping @Sendable (String) async throws -> Event,
        provider: PriceHistoryProvider,
        makeSocialStrip: @escaping @MainActor (String, String?, [Market]) -> SocialStripViewModel
    ) {
        self.mover = mover
        self.fetchEvent = fetchEvent
        self.provider = provider
        self.makeSocialStrip = makeSocialStrip
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

    /// Loads the parent event, builds the social strip, and — for chart-layout events —
    /// builds/loads the multi-series chart (date-ladder events render straight from
    /// `dateLadderMarkets` — no chart needed). Idempotent: skips if already loaded.
    public func load() async {
        guard event == nil, !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let event = try await fetchEvent(mover.eventSlug)
            self.event = event
            let conditionId = event.markets.first { $0.id == mover.id }?.conditionId ?? event.markets.first?.conditionId
            socialStrip = makeSocialStrip(event.id, conditionId, event.markets)
            guard EventLayoutClassifier.classify(event.markets) == .chart else { return }
            let chart = EventChartViewModel(event: event, provider: provider)
            self.chart = chart
            await chart.load()
        } catch {
            errorMessage = "Couldn't load this market. Check your connection and try again."
        }
    }
}
