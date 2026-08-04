//
//  ClockGriddedSeries.swift
//  NextOutcome
//

import Foundation

/// A recurring market series whose event slugs are a Unix timestamp snapped to a fixed grid,
/// e.g. `btc-updown-5m-1785764400` for the 5-minute window starting at that instant.
///
/// This exists because the live window of such a series is **unreachable through any list
/// query**. A 5-minute market has `volume24hr`, `volume` and `liquidity` all `0` (it has no
/// history), and while its `endDate` is correct — exactly `slug epoch + windowSeconds` —
/// roughly 288 windows per asset per day are pre-created up to 24 hours ahead, so ordering
/// by `endDate` ascending hits long-abandoned never-closed windows first and descending hits
/// tomorrow's first. Reaching the nearest-future window by paging would cost several requests
/// every five minutes.
///
/// Computing the slug from the clock is one request and exact. It's also what Polymarket's
/// own web client does — its homepage pins the card via a `discovery-pin` keyed on exactly
/// this slug. See `docs/polymarket-crypto-hub-gaps.md` §2.
///
/// Not every recurring series works this way: the hourly BTC series uses human-readable slugs
/// (`bitcoin-up-or-down-august-3-2026-9am-et`) with no timestamp to compute, and needs a
/// different rule. Don't generalise this type onto it.
public struct ClockGriddedSeries: Sendable, Equatable {
    /// The slug text preceding the timestamp, e.g. `"btc-updown-5m"`.
    public let slugPrefix: String
    /// The window length in seconds, which is also the grid spacing, e.g. `300`.
    public let windowSeconds: Int

    /// Creates a series descriptor.
    /// - Parameters:
    ///   - slugPrefix: The slug text before the timestamp.
    ///   - windowSeconds: The window length and grid spacing, in seconds. Must be positive.
    public init(slugPrefix: String, windowSeconds: Int) {
        self.slugPrefix = slugPrefix
        self.windowSeconds = max(1, windowSeconds)
    }

    /// Bitcoin's 5-minute Up/Down series — the card `polymarket.com/crypto` leads with.
    public static let bitcoinUpDown5m = ClockGriddedSeries(slugPrefix: "btc-updown-5m", windowSeconds: 300)

    /// The start of the window containing `date`, snapped down to the grid.
    ///
    /// Uses floored division so instants before the epoch snap backwards too, rather than
    /// truncating toward zero and landing in the following window.
    public func windowStart(at date: Date) -> Date {
        let seconds = Int(date.timeIntervalSince1970.rounded(.down))
        let grid = Int((Double(seconds) / Double(windowSeconds)).rounded(.down)) * windowSeconds
        return Date(timeIntervalSince1970: TimeInterval(grid))
    }

    /// The slug of the window containing `date` — the live one when `date` is now.
    public func slug(at date: Date) -> String {
        "\(slugPrefix)-\(Int(windowStart(at: date).timeIntervalSince1970))"
    }

    /// When the window containing `date` closes and the next one becomes live.
    ///
    /// A refresh scheduled on this instant lands on the boundary rather than drifting, which
    /// a fixed-interval timer would do.
    public func nextBoundary(after date: Date) -> Date {
        windowStart(at: date).addingTimeInterval(TimeInterval(windowSeconds))
    }
}
