//
//  PitchSection.swift
//  NextOutcome
//
//  Created by Sok Pich on 03/07/2026.
//

import SwiftUI
import DesignSystem
import LiveStatsDomain

/// The "Pitch" section: a simple pitch graphic with a dot showing approximate ball
/// position. Falls back to the "Not available" row when the feed omits ball position.
struct PitchSection: View {
    /// The latest match snapshot to read `ballPositionPct` from.
    let match: MatchState?

    var body: some View {
        if let pct = match?.ballPositionPct {
            GeometryReader { geo in
                ZStack {
                    RoundedRectangle(cornerRadius: DSLayout.chipRadius)
                        .fill(DSColor.positive.opacity(0.25))
                    Rectangle().fill(DSColor.hairline).frame(width: 1) // halfway line
                    Circle().fill(DSColor.textPrimary)
                        .frame(width: 10, height: 10)
                        .position(x: geo.size.width * pct, y: geo.size.height / 2)
                }
            }
            .frame(height: 160)
        } else {
            UnavailableRow()
        }
    }
}
