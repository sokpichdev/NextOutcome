//
//  SportGroupCatalog.swift
//  NextOutcome
//
//  Created by Sok Pich on 16/08/2026.
//

import Foundation

/// The sport taxonomy — the one part of the catalogue Gamma will not tell us.
///
/// `GET /tags/{id}/related-tags/tags` returns an empty array for every sport group tag
/// (football, basketball, soccer, tennis, combat, motorsports, cricket — all checked
/// 2026-08-16), so the nesting in Polymarket's own All Sports sheet is hardcoded in their
/// frontend, and it is hardcoded here too.
///
/// This table is a *tuning knob, not a correctness requirement*: a league whose group can't
/// be resolved becomes its own top-level row, which is visible and usable. A sport
/// Polymarket adds tomorrow degrades to a working leaf, never to a missing chip or a crash.
public enum SportGroupCatalog {
    /// Group tag id → display name and SF Symbol.
    ///
    /// Esports (`64`) is listed here so its leagues can be *identified*, and it is filtered
    /// out downstream by `FetchSportsCatalogueUseCase` because it has its own hub.
    public static let groups: [String: (name: String, glyph: String)] = [
        "100350": ("Soccer", "soccerball"),
        "517":    ("Cricket", "figure.cricket"),
        "28":     ("Basketball", "basketball.fill"),
        "678":    ("Baseball", "baseball.fill"),
        "1186":   ("Football", "football.fill"),          // slug: american-football
        "100088": ("Hockey", "hockey.puck.fill"),
        "102193": ("Rugby", "figure.rugby"),
        "103767": ("Table Tennis", "figure.table.tennis"),
        "100219": ("Golf", "figure.golf"),
        "103838": ("Combat", "figure.boxing"),
        "434":    ("Motorsports", "flag.checkered"),      // slug: racing
        "102142": ("Cycling", "figure.outdoor.cycle"),
        "100277": ("Poker", "suit.spade.fill"),
        "256":    ("Chess", "checkerboard.rectangle"),
        "102471": ("Pickleball", "figure.pickleball"),
        "864":    ("Tennis", "figure.tennis"),
        "102883": ("Volleyball", "figure.volleyball"),
        "102897": ("Handball", "figure.handball"),
        "102393": ("Lacrosse", "figure.lacrosse"),
        "64":     ("Esports", "gamecontroller.fill"),
    ]

    /// League slug → group tag id, for leagues whose own tags omit their group.
    ///
    /// NFL is `1,450,100639` and CFB is `1,100351,100639` — neither carries the
    /// american-football tag their siblings UFL and CFL do. Same for F1 and IndyCar against
    /// NASCAR's `racing` tag.
    public static let overrides: [String: String] = [
        "nfl": "1186", "cfb": "1186",
        "f1": "434", "indycar": "434",
    ]

    /// Shown when a group's SF Symbol is unavailable on the running OS.
    public static let fallbackGlyph = "sportscourt.fill"

    /// Resolves which sport a league belongs to.
    ///
    /// Matches by *membership*, never by position: tag order is not dependable
    /// (LaLiga is `1,780,100639,100350`, with its group tag last).
    ///
    /// - Parameters:
    ///   - tagIDs: The league's tag ids, from `/sports`.
    ///   - slug: The league's slug, used to consult `overrides`.
    /// - Returns: The group's tag id, or `nil` when the league belongs to no group and so
    ///   becomes a top-level row of its own.
    public static func groupTagID(forTagIDs tagIDs: [String], slug: String) -> String? {
        tagIDs.first { groups[$0] != nil } ?? overrides[slug]
    }

    /// The display name and glyph for a group tag id, falling back to the tag id itself when
    /// the table doesn't know it (an unrecognised group still renders rather than vanishing).
    /// - Parameter tagID: The group's tag id.
    public static func presentation(forGroupTagID tagID: String) -> (name: String, glyph: String) {
        groups[tagID] ?? (name: tagID, glyph: fallbackGlyph)
    }
}
