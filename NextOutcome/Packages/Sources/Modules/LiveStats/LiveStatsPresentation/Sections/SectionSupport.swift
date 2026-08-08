//
//  SectionSupport.swift
//  NextOutcome
//
//  Created by Sok Pich on 03/07/2026.
//

import SwiftUI
import DesignSystem

/// Shown for any section the feed does not populate. Never a blank.
struct UnavailableRow: View {
    var body: some View {
        Text("Not available for this match")
            .font(DSFont.caption)
            .foregroundStyle(DSColor.textSecondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, DSLayout.spacingLarge)
    }
}

/// An opposing bar row: label centered, home value left, away value right, proportional fill.
struct OpposingStatRow: View {
    /// The stat's name shown centered above the bar (e.g. "Shots").
    let label: String
    /// The home team's value.
    let home: Int
    /// The away team's value.
    let away: Int

    /// The home team's share of the combined total, used to size the bar's left fill.
    /// Falls back to 0.5 (an even split) when both values are zero to avoid divide-by-zero.
    private var homeFraction: Double {
        let total = home + away
        return total == 0 ? 0.5 : Double(home) / Double(total)
    }

    var body: some View {
        VStack(spacing: DSLayout.spacingXSmall) {
            HStack {
                Text("\(home)").font(DSFont.caption.bold()).foregroundStyle(DSColor.textPrimary)
                Spacer()
                Text(label).font(DSFont.caption).foregroundStyle(DSColor.textSecondary)
                Spacer()
                Text("\(away)").font(DSFont.caption.bold()).foregroundStyle(DSColor.textPrimary)
            }
            GeometryReader { geo in
                HStack(spacing: 2) {
                    Capsule().fill(DSColor.accent)
                        .frame(width: geo.size.width * homeFraction)
                    Capsule().fill(DSColor.surfaceElevated)
                }
            }
            .frame(height: 4)
        }
    }
}
