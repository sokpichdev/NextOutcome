//
//  LineupsSection.swift
//  NextOutcome
//
//  Created by Sok Pich on 03/07/2026.
//

import SwiftUI
import DesignSystem
import LiveStatsDomain

struct LineupsSection: View {
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
