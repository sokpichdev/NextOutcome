//
//  ScoreHero.swift
//  NextOutcome
//
//  Created by Sok Pich on 03/07/2026.
//

import SwiftUI
import DesignSystem
import LiveStatsDomain

/// Pinned header for the Live sub-tab: clock/period, score, and the minute timeline.
/// Shows a "reconnecting" pill while the socket is re-establishing.
struct ScoreHero: View {
    let match: MatchState?
    let connection: MatchConnection

    var body: some View {
        VStack(spacing: DSLayout.spacingSmall) {
            HStack(spacing: DSLayout.spacingSmall) {
                periodLabel
                Spacer()
                if connection == .reconnecting {
                    reconnectingPill
                }
            }
            Text(scoreText)
                .font(DSFont.largeTitle)
                .monospacedDigit()
                .foregroundStyle(DSColor.textPrimary)
            MinuteTimelineBar(clockMinute: match?.clockMinute, events: match?.events ?? [])
        }
        .frame(maxWidth: .infinity)
        .padding(DSLayout.spacing)
        .background(DSColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: DSLayout.cardRadius))
    }

    private var scoreText: String {
        guard let match else { return "–  –" }
        return "\(match.home.goals)  \(match.away.goals)"
    }

    @ViewBuilder
    private var periodLabel: some View {
        if let period = match?.period {
            HStack(spacing: DSLayout.spacingXSmall) {
                if match?.isLive == true {
                    Circle().fill(DSColor.negative).frame(width: 6, height: 6)
                }
                Text(period).font(DSFont.caption.bold()).foregroundStyle(DSColor.textSecondary)
            }
        } else {
            Text("Live").font(DSFont.caption.bold()).foregroundStyle(DSColor.textSecondary)
        }
    }

    private var reconnectingPill: some View {
        Text("Reconnecting…")
            .font(DSFont.caption2)
            .foregroundStyle(DSColor.textSecondary)
            .padding(.horizontal, DSLayout.spacingSmall)
            .padding(.vertical, DSLayout.spacingXSmall)
            .background(DSColor.surfaceElevated)
            .clipShape(Capsule())
    }
}
