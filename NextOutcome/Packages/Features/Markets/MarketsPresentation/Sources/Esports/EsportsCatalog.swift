//
//  EsportsCatalog.swift
//  NextOutcome
//
//  Created by Sok Pich on 14/07/2026.
//

import SwiftUI
import MarketsDomain

/// The game titles the Esports hub features, in display order. Each maps to the Gamma tag
/// slug its match events carry (e.g. "counter-strike-2").
public enum EsportsGame: String, CaseIterable, Identifiable, Sendable {
    case cs2 = "counter-strike-2"
    case lol = "league-of-legends"
    case dota2 = "dota-2"

    public var id: String { rawValue }

    /// The short display name, matching web's game tiles ("CS2", "LoL", "Dota 2").
    public var title: String {
        switch self {
        case .cs2: return "CS2"
        case .lol: return "LoL"
        case .dota2: return "Dota 2"
        }
    }

    /// The longer name shown on match cards ("Counter-Strike 2", …).
    public var fullName: String {
        switch self {
        case .cs2: return "Counter-Strike 2"
        case .lol: return "League of Legends"
        case .dota2: return "Dota 2"
        }
    }

    /// The SF Symbol used where the game needs an icon.
    public var glyph: String {
        switch self {
        case .cs2: return "scope"
        case .lol: return "shield.lefthalf.filled"
        case .dota2: return "flame.fill"
        }
    }

    /// The artwork tile's gradient colours, standing in for web's key art.
    public var gradientColors: [Color] {
        switch self {
        case .cs2: return [Color(red: 0.95, green: 0.55, blue: 0.10), Color(red: 0.55, green: 0.25, blue: 0.02)]
        case .lol: return [Color(red: 0.85, green: 0.65, blue: 0.15), Color(red: 0.20, green: 0.35, blue: 0.55)]
        case .dota2: return [Color(red: 0.80, green: 0.20, blue: 0.15), Color(red: 0.30, green: 0.05, blue: 0.10)]
        }
    }
}

/// Pure classification helpers over the esports tag's events: which are live team-vs-team
/// matches (web's "Games" list) versus futures (season winners, MVP props), and which game
/// each belongs to. Mirrors the pattern of `SportsHubViewModel.knownLeagues` — presentation
/// owns the curated catalogue, Domain carries the raw signals (`tags`, `sportsMarketType`).
public enum EsportsCatalog {
    /// Whether an event is a team-vs-team match (rather than a futures/prop market):
    /// it carries a moneyline market, or Gamma's `games` tag, or a " vs " title.
    public static func isMatch(_ event: Event) -> Bool {
        if event.markets.contains(where: { $0.sportsMarketType?.localizedCaseInsensitiveContains("moneyline") == true }) {
            return true
        }
        if event.tags.contains(where: { $0.slug == "games" }) { return true }
        return event.title.range(of: " vs ", options: .caseInsensitive) != nil
            || event.title.range(of: " vs. ", options: .caseInsensitive) != nil
    }

    /// Resolves which featured game an event belongs to from its tag slugs, or `nil` for
    /// other titles (e.g. EA FC, Rocket League) the hub doesn't feature yet.
    public static func game(for event: Event) -> EsportsGame? {
        let slugs = Set(event.tags.map(\.slug))
        return EsportsGame.allCases.first { slugs.contains($0.rawValue) }
    }

    /// A parsed match title: the two team names and the series format, from Gamma's
    /// `"Counter-Strike: QUAZAR vs Brute (BO3) - ESL Challenger League ..."` shape.
    public struct MatchTitle: Equatable, Sendable {
        /// The first (home) team's name.
        public let homeTeam: String
        /// The second (away) team's name.
        public let awayTeam: String
        /// The series format (e.g. "BO3"), when the title carries one.
        public let seriesFormat: String?
        /// The tournament/league suffix after the trailing " - ", when present.
        public let tournament: String?
    }

    /// Parses a Gamma esports match title. Tolerates the optional "Game:" prefix,
    /// "(BOn)" series marker, and " - Tournament" suffix. Returns `nil` when no
    /// " vs " separator is found.
    public static func matchTitle(from title: String) -> MatchTitle? {
        // Strip the leading game prefix ("Counter-Strike: ", "LoL: ", …).
        var body = title
        if let colon = body.range(of: ": ") {
            body = String(body[colon.upperBound...])
        }
        // Split off the trailing " - Tournament" suffix.
        var tournament: String?
        if let dash = body.range(of: " - ", options: .backwards) {
            tournament = String(body[dash.upperBound...]).trimmingCharacters(in: .whitespaces)
            body = String(body[..<dash.lowerBound])
        }
        // Pull out a "(BO3)"-style series marker.
        var seriesFormat: String?
        if let open = body.range(of: "(", options: .backwards),
           let close = body.range(of: ")", options: .backwards),
           open.lowerBound < close.lowerBound {
            let inner = String(body[open.upperBound..<close.lowerBound])
            if inner.uppercased().hasPrefix("BO") {
                seriesFormat = inner.uppercased()
                body.removeSubrange(open.lowerBound..<close.upperBound)
            }
        }
        // Split the remaining "A vs B".
        guard let vs = body.range(of: " vs ", options: .caseInsensitive)
            ?? body.range(of: " vs. ", options: .caseInsensitive) else { return nil }
        let home = String(body[..<vs.lowerBound]).trimmingCharacters(in: .whitespaces)
        let away = String(body[vs.upperBound...]).trimmingCharacters(in: .whitespaces)
        guard !home.isEmpty, !away.isEmpty else { return nil }
        return MatchTitle(homeTeam: home, awayTeam: away, seriesFormat: seriesFormat, tournament: tournament)
    }

    /// The Twitch channel name from an event's `resolutionSource`
    /// (`https://www.twitch.tv/<channel>`), or `nil` when it isn't a Twitch URL.
    public static func twitchChannel(from resolutionSource: String?) -> String? {
        guard let source = resolutionSource,
              let url = URL(string: source),
              url.host?.contains("twitch.tv") == true else { return nil }
        let channel = url.pathComponents.first { $0 != "/" }
        return (channel?.isEmpty == false) ? channel : nil
    }
}
