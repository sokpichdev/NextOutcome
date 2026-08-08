//
//  EventLayoutClassifier.swift
//  NextOutcome
//
//  Created by Sok Pich on 05/07/2026.
//

/// Which end-date pattern an event's sibling markets follow. The Breaking movers listing
/// always renders as a list either way — this only decides *how to sort it* chronologically
/// (see `EventLayoutClassifier`).
public enum EventLayout: Sendable {
    /// Several mutually-exclusive candidates resolving on the *same* date (e.g. "GPT-5.6
    /// released on…?" — one market per specific day, all settling July 31). The specific day
    /// each candidate bets on lives only in its label text, not `endDate`.
    case chart
    /// A "by \<date\>" cumulative ladder (e.g. "GPT-5.6 released by…?" — one market per
    /// increasing deadline), where each market carries its own real, distinct `endDate`.
    case dateLadder
}

/// Pure classifier that decides which end-date pattern an event's sibling markets follow, so
/// the Breaking movers listing (`MoversDetailViewModel.listingMarkets`) knows whether to sort
/// candidates by their real `endDate` or by a date parsed out of each candidate's label.
public enum EventLayoutClassifier {
    /// Classifies an event's markets by whether they share one resolution date (`.chart`) or
    /// each resolve on their own distinct date (`.dateLadder`).
    ///
    /// The signal: multi-candidate events (e.g. "GPT-5.6 released on…?") give every market the
    /// *same* `endDate` — one shared settlement date — while date-ladder events give each
    /// market its own increasing `endDate` (May 31, June 5, June 8, …). Two or more distinct
    /// end dates among the markets means "each of these resolves at its own time," so `endDate`
    /// itself is a reliable sort key; a single shared end date means it isn't, and the real
    /// per-candidate date must be parsed from the label instead.
    /// - Parameter markets: The event's markets.
    /// - Returns: `.dateLadder` when markets carry 2+ distinct end dates, else `.chart`.
    public static func classify(_ markets: [Market]) -> EventLayout {
        let distinctEndDates = Set(markets.compactMap(\.endDate))
        return distinctEndDates.count > 1 ? .dateLadder : .chart
    }
}
