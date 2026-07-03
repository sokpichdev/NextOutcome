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
    let clockMinute: Int?
    let events: [MatchState.MatchEvent]

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

    private func progress(_ minute: Int) -> Double {
        min(1, max(0, Double(minute) / Self.fullMatch))
    }

    private func color(for kind: MatchState.EventKind) -> Color {
        switch kind {
        case .goal: return DSColor.positive
        case .yellowCard: return DSColor.categoryGold
        case .redCard: return DSColor.negative
        case .substitution: return DSColor.accent
        }
    }
}
