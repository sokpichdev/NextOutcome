//
//  SportsSort.swift
//  NextOutcome
//

import Foundation
import MarketsDomain

/// The sort applied to a Sports hub or league detail event list, chosen via the filter icon.
public enum SportsSort: String, CaseIterable, Sendable {
    /// Highest 24h volume first.
    case volume
    /// Soonest kickoff first; events without a kickoff time sort last.
    case soonest

    /// The label shown in the sort menu.
    public var title: String {
        switch self {
        case .volume:  return "Volume"
        case .soonest: return "Soonest"
        }
    }

    /// Sorts `events` by this sort's rule.
    public func apply(to events: [Event]) -> [Event] {
        switch self {
        case .volume:
            return events.sorted { $0.volume > $1.volume }
        case .soonest:
            return events.sorted {
                ($0.gameStartTime ?? .distantFuture, $0.id) < ($1.gameStartTime ?? .distantFuture, $1.id)
            }
        }
    }
}
