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

    /// Maps to the domain league, or `nil` when the row can't identify its events —
    /// without `primaryTagId` there is nothing to classify against, so a tile would be inert.
    func toDomain() -> EsportsLeague? {
        guard let primaryTagId else { return nil }
        return EsportsLeague(
            id: sport,
            name: name ?? sport,
            primaryTagID: String(primaryTagId),
            seriesID: series.flatMap { $0.isEmpty ? nil : $0 },
            iconURL: image.flatMap(URL.init(string:))
        )
    }
}
