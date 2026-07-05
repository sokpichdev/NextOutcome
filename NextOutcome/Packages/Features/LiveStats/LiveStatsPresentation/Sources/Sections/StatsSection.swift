//
//  StatsSection.swift
//  NextOutcome
//
//  Created by Sok Pich on 03/07/2026.
//

import SwiftUI
import DesignSystem
import LiveStatsDomain

/// The "Stats" section: a stack of opposing-bar rows (shots, corners, cards). Falls back
/// to the "Not available" row when the feed carries no detailed stats.
struct StatsSection: View {
    /// The latest match snapshot to read stats from.
    let match: MatchState?

    var body: some View {
        if let rows = statRows, !rows.isEmpty {
            VStack(spacing: DSLayout.spacing) {
                ForEach(rows.indices, id: \.self) { i in
                    OpposingStatRow(label: rows[i].label, home: rows[i].home, away: rows[i].away)
                }
            }
        } else {
            UnavailableRow()
        }
    }

    /// Builds the list of stat rows to display, including only stats where *both* teams'
    /// values are present (so half-populated stats are skipped rather than shown as 0).
    /// - Returns: The labelled home/away rows, or `nil` when there's no match yet.
    private var statRows: [(label: String, home: Int, away: Int)]? {
        guard let match else { return nil }
        var rows: [(String, Int, Int)] = []
        // Adds a row only when both teams reported the stat.
        func add(_ label: String, _ h: Int?, _ a: Int?) {
            if let h, let a { rows.append((label, h, a)) }
        }
        add("Shots on target", match.home.shotsOn, match.away.shotsOn)
        add("Shots off target", match.home.shotsOff, match.away.shotsOff)
        add("Corners", match.home.corners, match.away.corners)
        add("Yellow cards", match.home.yellowCards, match.away.yellowCards)
        add("Red cards", match.home.redCards, match.away.redCards)
        return rows.map { (label: $0.0, home: $0.1, away: $0.2) }
    }
}
