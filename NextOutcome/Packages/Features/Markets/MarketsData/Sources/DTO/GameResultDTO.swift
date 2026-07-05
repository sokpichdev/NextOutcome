//
//  GameResultDTO.swift
//  NextOutcome
//
//  Created by Sok Pich on 04/07/2026.
//

import Foundation
import MarketsDomain

/// Gamma `/events/results?id=<eventID>` payload — live/final sports scores plus team
/// metadata. Decoded tolerantly: any missing field degrades instead of failing the row.
struct GameResultDTO: Decodable {
    /// The event id (accepts string or int form).
    let id: String?
    /// The "home-away" score string.
    let score: String?
    /// Elapsed-time label.
    let elapsed: String?
    /// Period label.
    let period: String?
    /// Whether the game is live.
    let live: Bool?
    /// Whether the game has ended.
    let ended: Bool?
    /// The teams playing.
    let teams: [GameTeamDTO]?

    /// Tolerant decoder; any missing field degrades the row rather than failing it.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? (try? c.decode(Int.self, forKey: .id)).map(String.init)
        score = try? c.decode(String.self, forKey: .score)
        elapsed = try? c.decode(String.self, forKey: .elapsed)
        period = try? c.decode(String.self, forKey: .period)
        live = try? c.decode(Bool.self, forKey: .live)
        ended = try? c.decode(Bool.self, forKey: .ended)
        teams = try? c.decode([GameTeamDTO].self, forKey: .teams)
    }

    private enum CodingKeys: String, CodingKey {
        case id, score, elapsed, period, live, ended, teams
    }

    /// Maps to the domain entity. `fallbackEventID` covers payloads without an `id` field
    /// (the caller knows which event it asked for).
    func toDomain(fallbackEventID: String) -> GameResult {
        GameResult(
            eventID: id ?? fallbackEventID,
            score: score?.isEmpty == true ? nil : score,
            elapsed: elapsed?.isEmpty == true ? nil : elapsed,
            period: period?.isEmpty == true ? nil : period,
            live: live ?? false,
            ended: ended ?? false,
            teams: (teams ?? []).compactMap { $0.toDomain() }
        )
    }
}

/// Gamma team row within a game result.
struct GameTeamDTO: Decodable {
    /// The team's full name.
    let name: String?
    /// The team's abbreviation.
    let abbreviation: String?
    /// The team's logo URL string.
    let logo: String?
    /// The team's brand colour hex.
    let color: String?
    /// "home" or "away".
    let ordering: String?

    /// Tolerant decoder; all fields optional.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try? c.decode(String.self, forKey: .name)
        abbreviation = try? c.decode(String.self, forKey: .abbreviation)
        logo = try? c.decode(String.self, forKey: .logo)
        color = try? c.decode(String.self, forKey: .color)
        ordering = try? c.decode(String.self, forKey: .ordering)
    }

    private enum CodingKeys: String, CodingKey {
        case name, abbreviation, logo, color, ordering
    }

    /// Maps to the domain `GameTeam`, or `nil` for a nameless team. Percent-encodes logo
    /// URLs that contain spaces.
    /// - Returns: The domain team, or `nil` if the name is missing/empty.
    func toDomain() -> GameTeam? {
        guard let name, !name.isEmpty else { return nil }
        // Logo URLs can contain spaces ("...Cabo Verde-eaec07ae28.png") — percent-encode.
        let url = logo.flatMap {
            URL(string: $0) ?? $0.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed).flatMap(URL.init(string:))
        }
        return GameTeam(
            name: name,
            abbreviation: abbreviation?.isEmpty == true ? nil : abbreviation?.uppercased(),
            logoURL: url,
            colorHex: color,
            ordering: ordering ?? ""
        )
    }
}
