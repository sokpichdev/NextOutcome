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
    let id: String?
    let score: String?
    let elapsed: String?
    let period: String?
    let live: Bool?
    let ended: Bool?
    let teams: [GameTeamDTO]?

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

struct GameTeamDTO: Decodable {
    let name: String?
    let abbreviation: String?
    let logo: String?
    let color: String?
    let ordering: String?

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
