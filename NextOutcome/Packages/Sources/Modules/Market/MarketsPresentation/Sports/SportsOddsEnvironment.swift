//
//  SportsOddsEnvironment.swift
//  NextOutcome
//
//  Created by Sok Pich on 06/07/2026.
//

import SwiftUI

/// Propagates the Sports hub's Odds Format + Show Spreads/Totals choice down to every
/// `GameCard` it shows (Live, Futures, and any embedded league/World Cup content) without
/// threading the values through each intermediate view. Only `SportsHubView` sets these —
/// everywhere else (e.g. the World Cup hub reached directly from the Home tab) reads the
/// defaults below, so the setting stays scoped to the Sports hub as intended.
private struct OddsFormatKey: EnvironmentKey {
    static let defaultValue: OddsFormat = .price
}

private struct ShowSpreadsAndTotalsKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// The Sports hub's selected odds display format. Defaults to `.price` outside the hub.
    public var oddsFormat: OddsFormat {
        get { self[OddsFormatKey.self] }
        set { self[OddsFormatKey.self] = newValue }
    }

    /// Whether `GameCard` should also show spread/total markets. Defaults to `false` outside
    /// the Sports hub.
    public var showSpreadsAndTotals: Bool {
        get { self[ShowSpreadsAndTotalsKey.self] }
        set { self[ShowSpreadsAndTotalsKey.self] = newValue }
    }
}
