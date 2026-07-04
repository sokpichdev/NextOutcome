//
//  LineupsSection.swift
//  NextOutcome
//
//  Created by Sok Pich on 03/07/2026.
//

import SwiftUI
import DesignSystem
import LiveStatsDomain

/// The "Lineups" section: two columns of starters (home leading, away trailing) with
/// formations. Falls back to the "Not available" row when no lineups are provided.
struct LineupsSection: View {
    /// The latest match snapshot to read `lineups` from.
    let match: MatchState?

    var body: some View {
        if let lineups = match?.lineups,
           !(lineups.homeStarters.isEmpty && lineups.awayStarters.isEmpty) {
            HStack(alignment: .top, spacing: DSLayout.spacing) {
                column(formation: lineups.homeFormation, starters: lineups.homeStarters,
                       alignment: .leading)
                column(formation: lineups.awayFormation, starters: lineups.awayStarters,
                       alignment: .trailing)
            }
        } else {
            UnavailableRow()
        }
    }

    /// Builds one team's column: an optional formation header above the starter names.
    /// - Parameters:
    ///   - formation: The formation string, if known.
    ///   - starters: The starting player names.
    ///   - alignment: Whether to align the column leading (home) or trailing (away).
    private func column(formation: String?, starters: [String],
                        alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: DSLayout.spacingXSmall) {
            if let formation {
                Text(formation).font(DSFont.caption.bold()).foregroundStyle(DSColor.textSecondary)
            }
            ForEach(starters.indices, id: \.self) { i in
                Text(starters[i]).font(DSFont.caption).foregroundStyle(DSColor.textPrimary)
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
    }
}
