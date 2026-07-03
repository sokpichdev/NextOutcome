//
//  LiveSection.swift
//  NextOutcome
//
//  Created by Sok Pich on 03/07/2026.
//

import Foundation
import LiveStatsDomain

/// The chip-nav sections of the Live sub-tab, in display order.
public enum LiveSection: String, CaseIterable, Sendable {
    case stats, pitch, lineups, timeline, table, h2h

    public var title: String {
        switch self {
        case .stats: return "Stats"
        case .pitch: return "Pitch"
        case .lineups: return "Lineups"
        case .timeline: return "Timeline"
        case .table: return "Table"
        case .h2h: return "H2H"
        }
    }
}

/// Whether a section has data to show for the current match. Sections the public feed does
/// not populate resolve to `.unavailable`, which the UI renders as a "Not available for this
/// match" row — in-spec degradation, never a blank.
public enum SectionAvailability: Sendable, Equatable {
    case available
    case unavailable
}

public extension LiveSection {
    func availability(in state: MatchState?) -> SectionAvailability {
        guard let state else { return .unavailable }
        switch self {
        case .stats:
            let hasDetail = state.home.shotsOn != nil || state.home.corners != nil
                || state.home.yellowCards != nil || state.away.shotsOn != nil
                || state.away.corners != nil || state.away.yellowCards != nil
            return hasDetail ? .available : .unavailable
        case .pitch:
            return state.ballPositionPct != nil ? .available : .unavailable
        case .lineups:
            return state.lineups != nil ? .available : .unavailable
        case .timeline:
            let hasCommentary = !(state.commentary ?? []).isEmpty
            return (hasCommentary || !state.events.isEmpty) ? .available : .unavailable
        case .table, .h2h:
            return .unavailable
        }
    }
}
