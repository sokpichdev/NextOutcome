//
//  EsportsGameTile.swift
//  NextOutcome
//
//  Created by Sok Pich on 14/07/2026.
//

import SwiftUI
import DesignSystem

/// One artwork tile in the horizontal game row (CS2 / LoL / Dota 2): a gradient key-art
/// stand-in with the game glyph, an "N live" badge, and the game name. Tapping toggles
/// the hub's game filter; the selected tile shows an accent ring.
struct EsportsGameTile: View {
    /// The game this tile represents.
    let game: EsportsGame
    /// How many of its matches are currently live.
    let liveCount: Int
    /// Whether the tile is the active list filter.
    let isSelected: Bool
    /// Toggles the filter.
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topLeading) {
                LinearGradient(colors: game.gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                Image(systemName: game.glyph)
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(.white.opacity(0.25))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(DSLayout.spacingSmall)

                if liveCount > 0 {
                    HStack(spacing: 4) {
                        Circle().fill(.white).frame(width: 5, height: 5)
                        Text("\(liveCount) live").font(DSFont.caption2.bold())
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.55))
                    .clipShape(Capsule())
                    .padding(DSLayout.spacingSmall)
                }

                Text(game.title)
                    .font(DSFont.headline.bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .padding(DSLayout.spacingSmall)
            }
            .frame(width: 150, height: 130)
            .clipShape(RoundedRectangle(cornerRadius: DSLayout.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: DSLayout.cardRadius)
                    .strokeBorder(isSelected ? DSColor.accent : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}
