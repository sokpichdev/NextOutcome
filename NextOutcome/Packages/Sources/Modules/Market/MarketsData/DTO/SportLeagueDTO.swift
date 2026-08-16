//
//  SportLeagueDTO.swift
//  NextOutcome
//
//  Created by Sok Pich on 09/08/2026.
//

import Foundation
import MarketsDomain

/// One row of Gamma's `/sports` league catalogue — every league Polymarket runs markets for,
/// traditional sports and esports alike (434 rows at time of writing).
///
/// ```json
/// {"id": 37, "sport": "cs2", "name": "CS2",
///  "image": "https://polymarket-upload.s3.us-east-2.amazonaws.com/league-icons/cs2.png",
///  "tags": "1,100639,64,100780", "primaryTagId": 100780, "series": "10310"}
/// ```
struct SportLeagueDTO: Decodable {
    /// The league's slug (`"cs2"`, `"dota2"`, `"val"`).
    let sport: String
    /// The display name ("CS2", "Mobile Legends: Bang Bang").
    let name: String?
    /// Key-art URL string.
    let image: String?
    /// **Comma-separated** tag ids — the wire format really is a string, not an array
    /// (`"1,100639,64,100780"`). This is how the catalogue is scoped: esports leagues carry
    /// `64`.
    let tags: String?
    /// The tag id Gamma considers canonical for this league. Numeric on the wire.
    let primaryTagId: Int?
    /// The league's tournaments series id. A string on the wire, unlike `primaryTagId`.
    let series: String?

    /// The tag ids from the comma-separated `tags` field, whitespace-trimmed.
    var tagIDs: [String] {
        (tags ?? "").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    /// Maps to the domain league without activity data — the identity-only path the Esports
    /// hub uses.
    func toDomain() -> SportLeague? { toDomain(summary: nil) }

    /// Maps to the domain league, merging this row's `/sports/summary` counterpart when one
    /// exists.
    ///
    /// Returns `nil` when the row can't identify its events: without `primaryTagId` there is
    /// nothing to classify against, so a chip would be inert — better absent than dead.
    ///
    /// - Parameter summary: The matching summary row, keyed by the same slug. `nil` zeroes
    ///   the activity fields, which reads as "no open events" and filters the league out of
    ///   the nav row rather than showing an empty chip.
    func toDomain(summary: SportsSummaryDTO.League?) -> SportLeague? {
        guard let primaryTagId else { return nil }
        return SportLeague(
            id: sport,
            name: summary?.name ?? name ?? sport,
            primaryTagID: String(primaryTagId),
            groupTagID: SportGroupCatalog.groupTagID(forTagIDs: tagIDs, slug: sport),
            seriesID: series.flatMap { $0.isEmpty ? nil : $0 },
            iconURL: (summary?.image ?? image).flatMap(URL.init(string:)),
            activeEventCount: summary?.activeEventCount ?? 0,
            hasLive: summary?.hasLive ?? false,
            volume: Decimal(summary?.volume ?? 0),
            eventDates: summary?.eventDates ?? []
        )
    }
}
