//
//  LeagueStandingsSheet.swift
//  NextOutcome
//

import SwiftUI
import MarketsDomain
import DesignSystem

/// The sheet opened from a league detail screen's trophy icon: the league's highest-volume
/// "champion"-style market, ranked — reuses the same bar-chart row the Futures tab uses.
struct LeagueStandingsSheet: View {
    /// The league this sheet shows standings for (used only for the empty-state message).
    let leagueTitle: String
    /// The ranked market to show, or `nil` if the league has no futures/props market yet.
    let event: Event?

    var body: some View {
        VStack(alignment: .leading, spacing: DSLayout.spacing) {
            Text("\(leagueTitle) Standings")
                .font(DSFont.title)
                .foregroundStyle(DSColor.textPrimary)
            if let event {
                FuturesOddsCard(event: event)
            } else {
                StateView(.empty).frame(maxHeight: .infinity)
            }
            Spacer(minLength: 0)
        }
        .padding(DSLayout.margin)
        .background(DSColor.background)
    }
}
