//
//  EsportsSeriesScore.swift
//  NextOutcome
//
//  Created by Sok Pich on 10/08/2026.
//

import Foundation

/// The two sides of an esports score, in Gamma's home/away ordering.
public struct EsportsScorePair: Equatable, Sendable {
    /// The home side's figure.
    public let home: Int
    /// The away side's figure.
    public let away: Int

    /// Creates a score pair.
    public init(home: Int, away: Int) {
        self.home = home
        self.away = away
    }

    /// Parses a `"home-away"` pair (`"5-5"`, `"000-000"`), or `nil` when malformed.
    /// Zero-padding is what the feed sends for an un-started map, so `"000"` reads as `0`.
    static func parse(_ raw: some StringProtocol) -> EsportsScorePair? {
        let parts = raw.split(separator: "-")
        guard parts.count == 2,
              let home = Int(parts[0].trimmingCharacters(in: .whitespaces)),
              let away = Int(parts[1].trimmingCharacters(in: .whitespaces))
        else { return nil }
        return EsportsScorePair(home: home, away: away)
    }
}

/// A parsed esports `score` string from Gamma's sports feed.
///
/// The feed packs three things into one pipe-separated field —
/// `"<currentMapScore>|<seriesScore>|<format>"`, e.g. `"000-000|1-1|Bo3"`. The first segment
/// is the score of the map **currently being played** (a live LoL game sends `"5-5|0-0|Bo3"`),
/// not a per-map history: once a map ends its score is gone, so a finished map's round score
/// is not recoverable from any Polymarket API. The second segment is the series score — maps
/// won so far — and the third names the format.
///
/// Some events send the bare `"1-0"` shape with no pipes; that is read as the series score.
public struct EsportsSeriesScore: Equatable, Sendable {
    /// The score of the map currently in progress, when the feed reports one.
    public let mapScore: EsportsScorePair?
    /// Maps won so far by each side.
    public let seriesScore: EsportsScorePair?
    /// The raw format marker (`"Bo3"`), when present.
    public let format: String?

    /// Creates a parsed score.
    public init(mapScore: EsportsScorePair?, seriesScore: EsportsScorePair?, format: String?) {
        self.mapScore = mapScore
        self.seriesScore = seriesScore
        self.format = format
    }

    /// How many maps the format spans (`"Bo3"` → 3), or `nil` when the format is absent or
    /// unrecognised.
    public var bestOf: Int? {
        guard let format else { return nil }
        let trimmed = format.trimmingCharacters(in: .whitespaces)
        guard trimmed.lowercased().hasPrefix("bo") else { return nil }
        guard let count = Int(trimmed.dropFirst(2)), count >= 1 else { return nil }
        return count
    }

    /// Parses a feed score string. Returns `nil` when nothing at all could be read, so a
    /// caller can tell "no score yet" from "a score of zero".
    /// - Parameter raw: The feed's `score` field.
    public static func parse(_ raw: String?) -> EsportsSeriesScore? {
        guard let raw, !raw.isEmpty else { return nil }
        let segments = raw.split(separator: "|", omittingEmptySubsequences: false)

        let mapScore: EsportsScorePair?
        let seriesScore: EsportsScorePair?
        if segments.count >= 2 {
            mapScore = EsportsScorePair.parse(segments[0])
            seriesScore = EsportsScorePair.parse(segments[1])
        } else {
            // The bare "1-0" shape carries the series score and nothing else.
            mapScore = nil
            seriesScore = segments.first.flatMap(EsportsScorePair.parse)
        }

        let format = segments.count >= 3
            ? segments[2].trimmingCharacters(in: .whitespaces).nilWhenEmpty
            : nil

        guard mapScore != nil || seriesScore != nil || format != nil else { return nil }
        return EsportsSeriesScore(mapScore: mapScore, seriesScore: seriesScore, format: format)
    }
}

/// How far through a series a match is, parsed from Gamma's `period` field (`"3/3"`).
public struct EsportsMatchProgress: Equatable, Sendable {
    /// The map currently being played, 1-based.
    public let currentMap: Int
    /// How many maps the series spans.
    public let totalMaps: Int

    /// Creates a progress marker.
    public init(currentMap: Int, totalMaps: Int) {
        self.currentMap = currentMap
        self.totalMaps = totalMaps
    }

    /// Parses `"<currentMap>/<totalMaps>"`. Returns `nil` for the period labels other sports
    /// send (`"1H"`, `"HT"`, `"FT"`), which carry no map count.
    /// - Parameter period: The feed's `period` field.
    public static func parse(_ period: String?) -> EsportsMatchProgress? {
        guard let period else { return nil }
        let parts = period.split(separator: "/")
        guard parts.count == 2,
              let current = Int(parts[0].trimmingCharacters(in: .whitespaces)),
              let total = Int(parts[1].trimmingCharacters(in: .whitespaces)),
              total >= 1
        else { return nil }
        return EsportsMatchProgress(currentMap: current, totalMaps: total)
    }
}

private extension String {
    /// The string, or `nil` when it is empty — for optional fields the feed pads rather than omits.
    var nilWhenEmpty: String? { isEmpty ? nil : self }
}
