//
//  EsportsGameTile.swift
//  NextOutcome
//
//  Created by Sok Pich on 14/07/2026.
//

import SwiftUI
import MarketsDomain
import DesignSystem

/// One tile in the horizontal game row: the league's logo on a gradient ground, an "N live"
/// badge, and the game name. Tapping toggles the hub's game filter; the selected tile shows an
/// accent ring.
///
/// The mark is the league's own `iconURL` from Gamma's catalogue, and it is a *logo*, not key
/// art — every esports row serves a square icon, and half of them are tiny (CS2, Dota 2 and
/// Honor of Kings are 28–30 px). This tile originally scaled that to fill 150×130, which made
/// a square logo span the tile edge to edge, crop top and bottom, and upscale the 30 px ones
/// about fivefold into a visible blur. It's now drawn as what it is: fitted, bounded, and
/// centred on the ground, upscaled at most ~2× so the small icons stay crisp.
///
/// The gradient is no longer only a loading state, then — it's the tile's actual background,
/// which is what the hand-written per-game gradients this replaced were too.
struct EsportsGameTile: View {
    /// The league this tile represents.
    let league: EsportsLeague
    /// How many of its matches are currently live.
    let liveCount: Int
    /// Whether the tile is the active list filter.
    let isSelected: Bool
    /// Toggles the filter.
    let action: () -> Void

    /// The tile's footprint.
    private static let size = CGSize(width: 150, height: 130)
    /// The logo's box. Sized against the smallest icons the catalogue serves (28 px) rather
    /// than the largest: past roughly double, upscaling those is plainly visible.
    private static let logoSize: CGFloat = 56
    /// The band the name occupies along the bottom — its line height plus the padding it
    /// already carries. Kept clear of the logo.
    private static let nameStripHeight: CGFloat = 30

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topLeading) {
                placeholderArt
                // Centred in the space above the name rather than in the whole tile, so the
                // logo reads as centred next to the label instead of sitting behind it. The
                // strip is reserved explicitly — padding the logo would grow the stack rather
                // than inset it.
                VStack(spacing: 0) {
                    artwork
                        .frame(width: Self.logoSize, height: Self.logoSize)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    Color.clear.frame(height: Self.nameStripHeight)
                }

                // Keeps the name legible when a logo's lower edge sits close to it.
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
            .frame(width: Self.size.width, height: Self.size.height)
            .clipShape(RoundedRectangle(cornerRadius: DSLayout.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: DSLayout.cardRadius)
                    .strokeBorder(isSelected ? DSColor.accent : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(liveCount > 0 ? "\(league.name), \(liveCount) live" : league.name)
    }

    /// The league's logo, fitted so the whole mark is visible whatever its aspect, and drawn
    /// with high interpolation because the catalogue's smallest icons are 28 px square.
    ///
    /// The placeholder is `Color.clear`, not the gradient: the gradient is already painted
    /// behind this, and a second copy would flash over it on load. A game with no icon simply
    /// shows the ground and its name.
    @ViewBuilder
    private var artwork: some View {
        if let iconURL = league.iconURL {
            AsyncImage(url: iconURL) { image in
                image
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                Color.clear
            }
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
