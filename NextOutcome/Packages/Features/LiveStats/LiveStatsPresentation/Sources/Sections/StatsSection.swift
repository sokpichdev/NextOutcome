//
//  StatsSection.swift
//  NextOutcome
//
//  Created by Sok Pich on 03/07/2026.
//

import SwiftUI
import DesignSystem
import LiveStatsDomain

struct StatsSection: View {
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

    private var statRows: [(label: String, home: Int, away: Int)]? {
        guard let match else { return nil }
        var rows: [(String, Int, Int)] = []
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
