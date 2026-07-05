//
//  BreakingHeroBanner.swift
//  NextOutcome
//
//  Created by Sok Pich on 05/07/2026.
//

import SwiftUI
import DesignSystem

/// The dated "Breaking News" hero card at the top of the Breaking feed — a decorative
/// header (matching the live site's banner) with today's date, the title, and an upward
/// arrow motif over a subtle gradient.
struct BreakingHeroBanner: View {
    /// Today's date, formatted like "Jul 5, 2026".
    private var dateText: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f.string(from: Date())
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: DSLayout.cardRadius)
                .fill(
                    LinearGradient(
                        colors: [DSColor.surfaceElevated, DSColor.accent.opacity(0.25)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image(systemName: "arrow.up.forward")
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(DSColor.accent)
                .padding(DSLayout.spacingLarge)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DSLayout.spacingXSmall) {
                Text(dateText)
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.textSecondary)
                Text("Breaking News")
                    .font(DSFont.title)
                    .foregroundStyle(DSColor.textPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DSLayout.spacingLarge)
        }
        .frame(height: 120)
        .clipShape(RoundedRectangle(cornerRadius: DSLayout.cardRadius))
    }
}
