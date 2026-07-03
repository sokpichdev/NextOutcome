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
    let label: String
    let home: Int
    let away: Int

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
