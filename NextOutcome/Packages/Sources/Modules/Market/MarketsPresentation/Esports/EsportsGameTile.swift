//
//  EsportsGameTile.swift
//  NextOutcome
//
//  Created by Sok Pich on 14/07/2026.
//

import SwiftUI
import MarketsDomain
import DesignSystem

/// One artwork tile in the horizontal game row: the league's key art under a bottom scrim,
/// an "N live" badge, and the game name. Tapping toggles the hub's game filter; the selected
/// tile shows an accent ring.
///
/// The art is the league's own `iconURL` from Gamma's catalogue. Before that landed each game
/// had a hand-written two-stop gradient in code, which is why the placeholder below is still a
/// gradient — it's the same idea, now only a loading state rather than the artwork itself.
struct EsportsGameTile: View {
    /// The league this tile represents.
    let league: EsportsLeague
    /// How many of its matches are currently live.
    let liveCount: Int
    /// Whether the tile is the active list filter.
    let isSelected: Bool
    /// Toggles the filter.
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topLeading) {
                artwork
                // Keeps the name legible over arbitrary key art.
                LinearGradient(
                    colors: [.clear, .black.opacity(0.75)],
                    startPoint: .center,
                    endPoint: .bottom
                )

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

                Text(league.name)
                    .font(DSFont.headline.bold())
                    .foregroundStyle(.white)
                    .lineLimit(1)
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
        .accessibilityLabel(liveCount > 0 ? "\(league.name), \(liveCount) live" : league.name)
    }

    /// The league key art, falling back to a neutral gradient while it loads or when the
    /// catalogue carries no image for this game.
    @ViewBuilder
    private var artwork: some View {
        if let iconURL = league.iconURL {
            AsyncImage(url: iconURL) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                placeholderArt
            }
        } else {
            placeholderArt
        }
    }

    private var placeholderArt: some View {
        LinearGradient(
            colors: [DSColor.surfaceElevated, DSColor.surface],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
