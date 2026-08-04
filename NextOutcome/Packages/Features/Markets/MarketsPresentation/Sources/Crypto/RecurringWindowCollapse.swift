//
//  RecurringWindowCollapse.swift
//  NextOutcome
//

import Foundation
import MarketsDomain

/// Collapses a recurring cadence series down to the one window worth showing.
///
/// Gamma pre-creates roughly 24 hours of windows ahead for each cadence series, so the Crypto
/// tag returns ~127 five-minute windows across just 7 series (one per asset). Listing all of
/// them is why our timeframe chips read `5 Min 132` where the web reads `5 Min 7` — the web
/// shows one card per *series*, not per window. Collapsing here fixes the list and the counts
/// together, since both derive from the same classified set.
///
/// **Known limitation.** This picks the earliest window that has not yet closed, which is the
/// live one *when the live one was fetched*. It often isn't: a window that just opened has
/// near-zero volume, and the tag fetch is ordered by 24-hour volume, so only high-volume
/// series (BTC) reliably have their current window in the payload. For quieter assets this
/// can show the next window instead of the current one — both are open and tradeable, so the
/// card is never wrong, just early. Resolving the true live window per series needs the
/// clock-arithmetic lookup `ClockGriddedSeries` does, at one request per series; that's worth
/// it for the pinned BTC card and not obviously worth ~39 requests for the whole list.
/// See `docs/polymarket-crypto-hub-gaps.md` §5(c).
enum RecurringWindowCollapse {
    /// Slug suffixes that mark a *recurring window* series.
    ///
    /// Matching on the suffix is deliberate. `Event.recurrence` is `series[0].slug`, which for
    /// esports is a category series (`league-of-legends`) rather than a repeating window —
    /// collapsing on the mere presence of a series would erase the Esports hub.
    static let cadenceSuffixes = ["-5m", "-15m", "-hourly", "-4h", "-daily"]

    /// Whether a series slug denotes a recurring window series.
    static func isCadenceSeries(_ slug: String?) -> Bool {
        guard let slug else { return false }
        return cadenceSuffixes.contains { slug.hasSuffix($0) }
    }

    /// Keeps one window per cadence series — the earliest that hasn't closed at `now` —
    /// and passes everything else through untouched, preserving the original order.
    /// - Parameters:
    ///   - items: The classified events.
    ///   - now: The instant to judge windows against.
    /// - Returns: The collapsed list.
    static func collapse(
        _ items: [(event: Event, kind: CryptoMarketKind)],
        asOf now: Date
    ) -> [(event: Event, kind: CryptoMarketKind)] {
        // The id to keep for each cadence series.
        var keep: [String: String] = [:]
        var best: [String: Date] = [:]
        for item in items {
            guard let series = item.event.recurrence, isCadenceSeries(series) else { continue }
            // A window with no end date can't be ordered; it's kept unconditionally below.
            guard let end = item.event.endDate, end > now else { continue }
            if best[series] == nil || end < best[series]! {
                best[series] = end
                keep[series] = item.event.id
            }
        }
        return items.filter { item in
            guard let series = item.event.recurrence, isCadenceSeries(series) else { return true }
            // No end date means we can't judge it — keep it rather than silently drop it.
            guard item.event.endDate != nil else { return true }
            return keep[series] == item.event.id
        }
    }
}
