//
//  TeamProfileTarget.swift
//  NextOutcome
//

import Foundation

/// A lightweight team/fighter identity used to open `TeamProfileView`. Built from
/// whichever team data a game card has available — a loaded `GameResult`'s
/// `GameTeam` when live scores are wired up, or (when no result has loaded) the
/// team's own moneyline market name/image.
public struct TeamProfileTarget: Identifiable, Hashable, Sendable {
    /// The team/fighter's display name — also used to match their markets.
    public let name: String
    /// The team/fighter's logo/photo, if any.
    public let logoURL: URL?
    /// The team's brand colour hex, if any.
    public let colorHex: String?
    /// Gamma's `/teams` league slug (e.g. "ufc", "mlb", "fifwc"), used to look up
    /// the team's record. `nil` for leagues with no team directory (e.g.
    /// Wimbledon, Combat) — the profile simply shows no record.
    public let league: String?

    /// Identity for navigation — a team's name uniquely identifies it within one
    /// league's roster.
    public var id: String { name }

    /// Creates a team profile target.
    public init(name: String, logoURL: URL?, colorHex: String?, league: String?) {
        self.name = name
        self.logoURL = logoURL
        self.colorHex = colorHex
        self.league = league
    }
}
