//
//  EsportsCatalog.swift
//  NextOutcome
//
//  Created by Sok Pich on 14/07/2026.
//

import Foundation
import MarketsDomain

/// Pure classification helpers over the esports tag's events: which are live team-vs-team
/// matches (web's "Games" list) versus futures (season winners, MVP props), and which game
/// each belongs to.
///
/// The game catalogue itself is *not* here — it's fetched from Gamma's `/sports` endpoint as
/// `[EsportsLeague]` (see `FetchEsportsLeaguesUseCase`). These functions take that list as an
/// argument rather than owning it, which is what lets the hub render a game it has never
/// heard of.
public enum EsportsCatalog {
    /// Whether an event is an esports match — the test for "should this push the esports
    /// match screen?" from a feed that isn't already scoped to esports.
    ///
    /// `isMatch` alone is **not** that test, and using it as one is a trap: it separates
    /// matches from futures *within* the esports tag, so it answers true for anything with a
    /// moneyline market or a `" vs "` title — which is every NFL, MLB and WNBA game in the
    /// general feed. ("Kansas City Royals vs. Los Angeles Dodgers" even carries the `games`
    /// tag that `isMatch` reads.) Routing on it from the All feed would send regular sports
    /// games to the esports scoreboard.
    ///
    /// The esports tag is the discriminator that holds in both directions: every event under
    /// Gamma's esports tag carries it, and no traditional-sports event does — they carry
    /// `sports`/`games` instead. Checked by **id**, not slug, for the reason given on
    /// `league(for:in:)`: game tag slugs are inconsistent, ids are not.
    public static func isEsportsMatch(_ event: Event) -> Bool {
        event.tags.contains { $0.id == FetchEsportsLeaguesUseCase.esportsTagID } && isMatch(event)
    }

    /// Whether an event is a team-vs-team match (rather than a futures/prop market):
    /// it carries a moneyline market, or Gamma's `games` tag, or a " vs " title.
    ///
    /// Only meaningful for events already known to be esports — see `isEsportsMatch(_:)`
    /// before reaching for this from a general feed.
    public static func isMatch(_ event: Event) -> Bool {
        if event.markets.contains(where: { $0.sportsMarketType?.localizedCaseInsensitiveContains("moneyline") == true }) {
            return true
        }
        if event.tags.contains(where: { $0.slug == "games" }) { return true }
        return event.title.range(of: " vs ", options: .caseInsensitive) != nil
            || event.title.range(of: " vs. ", options: .caseInsensitive) != nil
    }

    /// Resolves which league an event belongs to, or `nil` when it carries none of their tags.
    ///
    /// Matches on **tag id**, not slug. Slugs are not a reliable key here: CS2 events carry
    /// `cs2` (`100677`), `counter-strike-2` (`100780`) and the typo `counter-stike-2`, and
    /// Valorant events carry both `valorant` and `val`. `EsportsLeague.primaryTagID` is
    /// Gamma's own answer to which of those is canonical, so comparing ids is both simpler
    /// and strictly more accurate than any slug list we could maintain.
    public static func league(for event: Event, in leagues: [EsportsLeague]) -> EsportsLeague? {
        let tagIDs = Set(event.tags.map(\.id))
        return leagues.first { tagIDs.contains($0.primaryTagID) }
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
