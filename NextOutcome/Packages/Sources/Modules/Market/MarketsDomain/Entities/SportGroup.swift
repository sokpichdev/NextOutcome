//
//  SportGroup.swift
//  NextOutcome
//

import Foundation

/// A sport as the nav row and the All Sports sheet present it: Soccer, Cricket, MLB.
///
/// A group holds one or more leagues and derives its own totals from them, so "Soccer 6.3K"
/// is the sum across its 169 leagues rather than a separately-fetched number.
public struct SportGroup: Identifiable, Hashable, Sendable {
    /// The group's tag id, or — for a league that belongs to no group — that league's slug.
    public let id: String
    /// The display name ("Soccer", "Table Tennis", "MLB").
    public let name: String
    /// The SF Symbol shown when no league key art is available.
    public let glyph: String
    /// The group's leagues, highest volume first.
    public let leagues: [SportLeague]

    /// Creates a group.
    public init(id: String, name: String, glyph: String, leagues: [SportLeague]) {
        self.id = id
        self.name = name
        self.glyph = glyph
        self.leagues = leagues
    }

    /// Open events across every league in the group — the chip's count badge.
    public var activeEventCount: Int { leagues.reduce(0) { $0 + $1.activeEventCount } }
    /// Whether any league in the group has a game in play.
    public var hasLive: Bool { leagues.contains(where: \.hasLive) }
    /// Total traded volume across the group, used to rank it.
    public var volume: Decimal { leagues.reduce(0) { $0 + $1.volume } }
    /// Whether this group is a single league, and so renders as a flat row with a count
    /// rather than an expandable one. MLB and UFC reach the sheet this way.
    public var isLeaf: Bool { leagues.count == 1 }
}
