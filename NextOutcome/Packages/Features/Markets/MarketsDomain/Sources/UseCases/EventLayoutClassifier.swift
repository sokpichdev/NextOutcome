//
//  EventLayoutClassifier.swift
//  NextOutcome
//
//  Created by Sok Pich on 05/07/2026.
//

/// Which detail layout an event's markets should render with.
public enum EventLayout: Sendable {
    /// Several mutually-exclusive outcomes resolving on the *same* date (e.g. "World Cup
    /// Winner" — one market per country) — rendered as one overlaid multi-series chart.
    case chart
    /// A "by \<date\>" cumulative ladder (e.g. "GPT-5.6 released by…?" — one market per
    /// increasing deadline) — rendered as a scrollable list of per-date rows, each with its
    /// own headline chance and Buy Yes/No, since there's no single shared resolution date to
    /// chart the outcomes against.
    case dateLadder
}

/// Pure classifier that decides how an event's sibling markets should be displayed.
public enum EventLayoutClassifier {
    /// Classifies an event's markets by whether they share one resolution date (`.chart`) or
    /// each resolve on their own distinct date (`.dateLadder`).
    ///
    /// The signal: multi-candidate events (World Cup Winner) give every market the *same*
    /// `endDate` — the tournament's one resolution date — while date-ladder events give each
    /// market its own increasing `endDate` (May 31, June 5, June 8, …). Two or more distinct
    /// end dates among the markets means "each of these resolves at its own time," which a
    /// single overlaid chart can't represent meaningfully.
    /// - Parameter markets: The event's markets.
    /// - Returns: `.dateLadder` when markets carry 2+ distinct end dates, else `.chart`.
    public static func classify(_ markets: [Market]) -> EventLayout {
        let distinctEndDates = Set(markets.compactMap(\.endDate))
        return distinctEndDates.count > 1 ? .dateLadder : .chart
    }
}
