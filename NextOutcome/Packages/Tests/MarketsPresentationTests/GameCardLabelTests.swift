//
//  GameCardLabelTests.swift
//  NextOutcome
//
//  Created by Sok Pich on 16/08/2026.
//

import XCTest
@testable import MarketsPresentation
import MarketsDomain

/// The short label on a game card's price buttons ("ARS", "DRAW", "MCI").
@MainActor
final class GameCardLabelTests: XCTestCase {
    private func team(_ name: String, _ abbreviation: String?) -> GameTeam {
        GameTeam(name: name, abbreviation: abbreviation, logoURL: nil, colorHex: nil, ordering: "home")
    }

    func test_prefersTheResultTeamsAbbreviation() {
        let label = GameCardLabel.shortLabel(
            groupItemTitle: "Arsenal FC", question: "Arsenal FC vs. Manchester City",
            index: 0, teams: [team("Arsenal FC", "ARS"), team("Manchester City", "MCI")], isDraw: false
        )

        XCTAssertEqual(label, "ARS")
    }

    func test_drawIsAlwaysLabelledDraw() {
        let label = GameCardLabel.shortLabel(
            groupItemTitle: "Draw (Arsenal vs City)", question: "q", index: 1, teams: [], isDraw: true
        )

        XCTAssertEqual(label, "DRAW")
    }

    func test_fallsBackToTheTeamAtThisMarketsPositionWhenThereIsNoItemTitle() {
        // The bug this fixes: tennis and table-tennis fixtures ship moneylines with no
        // groupItemTitle, so both sides fell back to the first three letters of the shared
        // event title and rendered "AZA" on BOTH price buttons.
        let teams = [team("Azarov Artem", nil), team("Serhyenko Ruslan", nil)]

        let home = GameCardLabel.shortLabel(groupItemTitle: nil, question: "Azarov Artem vs. Serhyenko Ruslan",
                                            index: 0, teams: teams, isDraw: false)
        let away = GameCardLabel.shortLabel(groupItemTitle: nil, question: "Azarov Artem vs. Serhyenko Ruslan",
                                            index: 1, teams: teams, isDraw: false)

        XCTAssertEqual(home, "AZA")
        XCTAssertEqual(away, "SER")
        XCTAssertNotEqual(home, away, "the two sides must never carry the same label")
    }

    func test_fallsBackToTheTitlePrefixWhenNothingElseIsKnown() {
        let label = GameCardLabel.shortLabel(groupItemTitle: nil, question: "Villarreal CF",
                                             index: 5, teams: [], isDraw: false)

        XCTAssertEqual(label, "VIL")
    }
}
