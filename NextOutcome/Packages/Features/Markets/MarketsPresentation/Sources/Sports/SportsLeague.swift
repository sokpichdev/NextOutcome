//
//  SportsLeague.swift
//  NextOutcome
//
//  Created by Sok Pich on 06/07/2026.
//

/// A sport/league chip shown in the Sports hub's tab bar (e.g. Wimbledon, MLB, UFC) —
/// resolved from the live tag catalogue so its id always matches the current feed.
public struct SportsLeague: Identifiable, Hashable, Sendable {
    /// The backing Gamma tag id, also used as this league's identity.
    public let id: String
    /// The chip's display label (e.g. "Wimbledon").
    public let title: String
    /// The SF Symbol shown on the chip.
    public let glyph: String

    /// Creates a league.
    public init(id: String, title: String, glyph: String) {
        self.id = id
        self.title = title
        self.glyph = glyph
    }
}
