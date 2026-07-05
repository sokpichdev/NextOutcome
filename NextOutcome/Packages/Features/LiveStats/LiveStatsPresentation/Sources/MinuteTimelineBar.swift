//
//  MinuteTimelineBar.swift
//  NextOutcome
//
//  Created by Sok Pich on 03/07/2026.
//

import SwiftUI
import DesignSystem
import LiveStatsDomain

/// A 0–90' progress bar with goal/card/sub markers positioned at `minute / 90`.
struct MinuteTimelineBar: View {
    /// The current match minute, used to fill the progress bar. `nil` shows no fill.
    let clockMinute: Int?
    /// Timeline events to plot as coloured dots along the bar.
    let events: [MatchState.MatchEvent]

    /// The reference full-match length in minutes used to place markers (`minute / 90`).
    private static let fullMatch: Double = 90

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(DSColor.surfaceElevated).frame(height: 4)
                if let clockMinute {
                    Capsule().fill(DSColor.accent)
                        .frame(width: width * progress(clockMinute), height: 4)
                }
                ForEach(events.indices, id: \.self) { i in
                    let event = events[i]
                    Circle()
                        .fill(color(for: event.kind))
                        .frame(width: 7, height: 7)
                        .offset(x: max(0, width * progress(event.minute) - 3.5))
                }
            }
            .frame(height: geo.size.height, alignment: .center)
        }
        .frame(height: 10)
    }

    /// Converts a match minute into a 0…1 fraction across the bar, clamped to that range.
    /// - Parameter minute: The match minute to position.
    /// - Returns: A fraction from 0 (kickoff) to 1 (full time).
    private func progress(_ minute: Int) -> Double {
        min(1, max(0, Double(minute) / Self.fullMatch))
    }

    /// Picks the marker colour for an event kind (green goal, gold/red cards, accent sub).
    /// - Parameter kind: The event type.
    /// - Returns: The colour to draw its dot.
    private func color(for kind: MatchState.EventKind) -> Color {
        switch kind {
        case .goal: return DSColor.positive
        case .yellowCard: return DSColor.categoryGold
        case .redCard: return DSColor.negative
        case .substitution: return DSColor.accent
        }
    }
}
