//
//  BreakingHeroBanner.swift
//  NextOutcome
//
//  Created by Sok Pich on 05/07/2026.
//

import SwiftUI
import DesignSystem

/// The dated "Breaking News" hero card at the top of the Breaking feed, matching the live
/// site's banner art: a dark-to-blue gradient card, a ripple of concentric arcs fanning out
/// from the trailing corner, and a solid blue circular badge with a white "trending up" arrow.
struct BreakingHeroBanner: View {
    /// Today's date, formatted like "Jul 5, 2026".
    private var dateText: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f.string(from: Date())
    }

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: DSLayout.cardRadius)
                .fill(
                    LinearGradient(
                        colors: [DSColor.surfaceElevated, DSColor.accent.opacity(0.35)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            rippleMotif
                .clipShape(RoundedRectangle(cornerRadius: DSLayout.cardRadius))

            VStack(alignment: .leading, spacing: DSLayout.spacingXSmall) {
                Text(dateText)
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.textSecondary)
                Text("Breaking News")
                    .font(DSFont.title)
                    .foregroundStyle(DSColor.textPrimary)
            }
            .padding(DSLayout.spacingLarge)
        }
        .frame(height: 120)
        .clipShape(RoundedRectangle(cornerRadius: DSLayout.cardRadius))
    }

    /// The concentric-arc ripple fanning from the badge, plus the badge itself — both
    /// anchored to the trailing edge, mirroring the live site's banner artwork.
    private var rippleMotif: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .stroke(DSColor.accent.opacity(0.25 - Double(i) * 0.07), lineWidth: 1.5)
                        .frame(width: 90 + CGFloat(i) * 55, height: 90 + CGFloat(i) * 55)
                }
                badge
            }
            .position(x: geo.size.width - 56, y: geo.size.height * 0.55)
        }
        .accessibilityHidden(true)
    }

    /// The solid blue circular badge with a white "trending up" arrow.
    private var badge: some View {
        Circle()
            .fill(DSColor.accent)
            .frame(width: 56, height: 56)
            .overlay {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
            }
            .shadow(color: DSColor.accent.opacity(0.5), radius: 12)
    }
}
