//
//  MoversDetailViewModel.swift
//  NextOutcome
//
//  Created by Sok Pich on 05/07/2026.
//

import Foundation
import MarketsDomain

/// Drives the bespoke movers detail screen. A mover is a single market, but the detail shows
/// a **listing** of all its *sibling* outcomes (the other markets of the same event) — one
/// row per candidate/deadline, each with its own chance and Buy Yes/No that opens the trade
/// sheet directly; tapping a row instead navigates to that specific market's own detail.
/// Fetches the full parent event by slug.
@MainActor
@Observable
public final class MoversDetailViewModel {
    /// The mover that opened this screen — supplies the header (question, chance, delta).
    public let mover: Mover
    /// The loaded parent event, once fetched. Its markets drive the listing.
    public private(set) var event: Event?
    /// The Comments/Top Holders/Positions/Activity social strip, built once the event loads.
    public private(set) var socialStrip: SocialStripViewModel?
    /// Whether the event fetch is in flight.
    public private(set) var isLoading = false
    /// A user-facing error message when the event fetch fails, else `nil`.
    public private(set) var errorMessage: String?

    /// The listing rows: the event's unresolved markets (closed candidates are old news),
    /// ordered chronologically to match the web. Events give every market its own distinct
    /// `endDate` (a "by \<date\>" cumulative ladder) or the *same* shared `endDate` (a
    /// "on \<date\>" pick-one, where the specific day instead lives in the label text) — see
    /// `EventLayoutClassifier`. Either way this sorts soonest-first; candidates whose date
    /// can't be determined sort last, by highest chance first. Empty before the event loads.
    public var listingMarkets: [Market] {
        guard let event else { return [] }
        let open = event.markets.filter { !$0.isResolved }
        let source = open.isEmpty ? event.markets : open
        let usesRealEndDates = EventLayoutClassifier.classify(event.markets) == .dateLadder
        return source.sorted { isEarlier($0, $1, usesRealEndDates: usesRealEndDates) }
    }

    /// Fetches the full parent event by slug.
    private let fetchEvent: @Sendable (String) async throws -> Event
    /// Builds the social strip view model from an event id, condition id, and markets.
    private let makeSocialStrip: @MainActor (String, String?, [Market]) -> SocialStripViewModel

    /// Creates the view model.
    /// - Parameters:
    ///   - mover: The tapped mover.
    ///   - fetchEvent: Fetches the parent event by slug.
    ///   - makeSocialStrip: Builds the Comments/Top Holders/Positions/Activity social strip.
    public init(
        mover: Mover,
        fetchEvent: @escaping @Sendable (String) async throws -> Event,
        makeSocialStrip: @escaping @MainActor (String, String?, [Market]) -> SocialStripViewModel
    ) {
        self.mover = mover
        self.fetchEvent = fetchEvent
        self.makeSocialStrip = makeSocialStrip
    }

    /// The market this mover refers to (matched by id within the event), falling back to the
    /// event's first market. Supplies the social strip's condition id.
    public var primaryMarket: Market? {
        guard let event else { return nil }
        return event.markets.first { $0.id == mover.id } ?? event.markets.first
    }

    /// The category breadcrumb shown under the back button (e.g. "Tech · AI"), built from the
    /// event's first couple of tags. Empty when the event isn't loaded or has no tags.
    public var categoryBreadcrumb: String {
        (event?.tags.prefix(2).map(\.label) ?? []).joined(separator: " · ")
    }

    /// Loads the parent event and builds the social strip. Idempotent: skips if already loaded.
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
        } catch {
            errorMessage = "Couldn't load this market. Check your connection and try again."
        }
    }

    /// Chronological comparator for two listing candidates.
    /// - Parameter usesRealEndDates: `true` when the event's markets carry distinct end dates
    ///   (use those directly); `false` when they share one settlement date (parse the date out
    ///   of the label text instead, since `endDate` alone can't distinguish candidates).
    private func isEarlier(_ lhs: Market, _ rhs: Market, usesRealEndDates: Bool) -> Bool {
        let lhsDate = candidateDate(lhs, usesRealEndDates: usesRealEndDates)
        let rhsDate = candidateDate(rhs, usesRealEndDates: usesRealEndDates)
        switch (lhsDate, rhsDate) {
        case let (l?, r?): return l < r
        case (nil, .some): return false   // undated candidates sort after dated ones
        case (.some, nil): return true
        case (nil, nil): return (lhs.yesOutcome?.price ?? 0) > (rhs.yesOutcome?.price ?? 0)
        }
    }

    /// The date to sort a candidate by: its real `endDate` for a date-ladder event, or a date
    /// parsed from its label text for a shared-end-date event.
    private func candidateDate(_ market: Market, usesRealEndDates: Bool) -> Date? {
        if usesRealEndDates { return market.endDate }
        return CandidateDateExtractor.extractedDate(from: market.groupItemTitle ?? market.question)
    }
}
