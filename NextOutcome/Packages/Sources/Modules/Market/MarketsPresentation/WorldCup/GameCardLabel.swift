//
//  GameCardLabel.swift
//  NextOutcome
//
//  Created by Sok Pich on 16/08/2026.
//

import Foundation
import MarketsDomain

/// Picks the short label a game card puts on a moneyline price button — "ARS", "DRAW", "MCI".
enum GameCardLabel {
    /// The label for one moneyline market.
    ///
    /// Resolution runs best-known-first: the result feed's abbreviation, then the team sitting
    /// at this market's position, then the market's own text. That middle step matters because
    /// tennis and table-tennis fixtures ship moneylines with no `groupItemTitle` — without it
    /// both sides fall back to the first three letters of the *shared* event title and render
    /// the same label on both buttons.
    ///
    /// - Parameters:
    ///   - groupItemTitle: The market's own team label, when Gamma sends one.
    ///   - question: The market question, used as the last resort.
    ///   - index: This market's position among the team markets (0 = home).
    ///   - teams: The result feed's teams, in the card's display order.
    ///   - isDraw: Whether this market is the draw outcome.
    static func shortLabel(
        groupItemTitle: String?, question: String, index: Int, teams: [GameTeam], isDraw: Bool
    ) -> String {
        if isDraw { return "DRAW" }
        let label = groupItemTitle ?? question
        if let matched = teams.first(where: { $0.name.caseInsensitiveCompare(label) == .orderedSame }) {
            return matched.abbreviation ?? String(matched.name.prefix(3)).uppercased()
        }
        if groupItemTitle == nil, teams.indices.contains(index) {
            let team = teams[index]
            return team.abbreviation ?? String(team.name.prefix(3)).uppercased()
        }
        return String(label.prefix(3)).uppercased()
    }
}
