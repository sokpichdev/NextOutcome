//
//  RecurrenceCadence.swift
//  NextOutcome
//
//  Created by Sok Pich on 18/08/2026.
//

import Foundation

/// How often a recurring market series opens a new window, read off the series slug.
///
/// `Event.recurrence` is `series[0].slug` (see `MarketMapper`), and the cadence is encoded
/// as its suffix — `btc-up-or-down-5m`, `eth-up-or-down-daily`. The slug suffix is used
/// rather than the JSON `recurrence` field, which Gamma doesn't populate consistently.
///
/// Matching on the *suffix* is deliberate: a series slug that carries no cadence at all
/// (`league-of-legends`, for esports) is not a recurring window series and must not be
/// treated as one.
public enum RecurrenceCadence: String, CaseIterable, Sendable {
    /// Five-minute windows.
    case fiveMinute = "-5m"
    /// Fifteen-minute windows.
    case fifteenMinute = "-15m"
    /// One-hour windows.
    case hourly = "-hourly"
    /// Four-hour windows.
    case fourHour = "-4h"
    /// One-day windows.
    case daily = "-daily"

    /// The cadence a series slug encodes, or `nil` for a slug that isn't a recurring
    /// window series (including `nil`).
    /// - Parameter seriesSlug: An `Event.recurrence` value.
    public init?(seriesSlug: String?) {
        guard let seriesSlug else { return nil }
        guard let match = Self.allCases.first(where: { seriesSlug.hasSuffix($0.rawValue) }) else { return nil }
        self = match
    }

    /// The window length in seconds.
    public var windowSeconds: TimeInterval {
        switch self {
        case .fiveMinute: return 300
        case .fifteenMinute: return 900
        case .hourly: return 3_600
        case .fourHour: return 14_400
        case .daily: return 86_400
        }
    }

    /// The short label Polymarket shows beside the asset, e.g. the `5m` of "BTC 5m" or the
    /// `Daily` of "ETH Daily".
    public var shortLabel: String {
        switch self {
        case .fiveMinute: return "5m"
        case .fifteenMinute: return "15m"
        case .hourly: return "1h"
        case .fourHour: return "4h"
        case .daily: return "Daily"
        }
    }
}
