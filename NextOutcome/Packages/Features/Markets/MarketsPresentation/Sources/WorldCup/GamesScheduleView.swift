//
//  GamesScheduleView.swift
//  NextOutcome
//
//  Created by Sok Pich on 04/07/2026.
//

import SwiftUI
import MarketsDomain
import DesignSystem

/// The hub's Games tab: match cards grouped under "Sat, July 4"-style day headers.
struct GamesScheduleView: View {
    let gamesByDay: [(day: Date, games: [Event])]
    let results: [String: GameResult]

    var body: some View {
        if gamesByDay.isEmpty {
            ContentUnavailableView("No games scheduled", systemImage: "sportscourt")
                .padding(.vertical, DSLayout.spacingXLarge)
        } else {
            LazyVStack(alignment: .leading, spacing: DSLayout.spacing) {
                ForEach(gamesByDay, id: \.day) { day, games in
                    Text(day, format: .dateTime.weekday(.abbreviated).month(.wide).day())
                        .font(DSFont.title3.bold())
                        .foregroundStyle(DSColor.textPrimary)
                        .padding(.top, DSLayout.spacingLarge)

                    ForEach(games) { game in
                        NavigationLink(value: game) {
                            GameCard(
                                event: game,
                                result: results[game.id],
                                moneyline: WorldCupEventSplitter.moneyline(for: game)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
