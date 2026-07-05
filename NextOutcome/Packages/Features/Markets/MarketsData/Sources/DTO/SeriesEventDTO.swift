//
//  SeriesEventDTO.swift
//  NextOutcome
//
//  Created by Sok Pich on 04/07/2026.
//

import Foundation
import MarketsDomain

/// `/events?series_id=` responses carry `gameStartTime` only on the embedded markets —
/// unlike single-event fetches, the event level omits it. This wrapper decodes the shared
/// `EventDTO` plus the per-market kickoffs so the repository can restore the event-level
/// kickoff without changing the shared decoding path.
struct SeriesEventDTO: Decodable {
    /// The decoded event (via the shared `EventDTO` path).
    let event: EventDTO
    /// The per-market kickoff strings, used to restore an event-level kickoff.
    private let kickoffs: [String]

    /// A minimal probe that reads only a market's `gameStartTime`.
    private struct KickoffProbe: Decodable {
        /// The market's kickoff string, if any.
        let gameStartTime: String?

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            gameStartTime = try? c.decode(String.self, forKey: .gameStartTime)
        }

        private enum CodingKeys: String, CodingKey { case gameStartTime }
    }

    private enum CodingKeys: String, CodingKey { case markets }

    /// Decodes the shared event plus the embedded markets' kickoff times.
    init(from decoder: Decoder) throws {
        event = try EventDTO(from: decoder)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        kickoffs = ((try? c.decode([KickoffProbe].self, forKey: .markets)) ?? [])
            .compactMap(\.gameStartTime)
    }

    /// The earliest market kickoff, used when the event itself carries none.
    var earliestKickoff: Date? {
        kickoffs.compactMap(DateParsing.parse).min()
    }

    /// Maps to the domain `Event`, restoring the event-level kickoff from the earliest
    /// market kickoff when the event itself carries none.
    /// - Returns: The domain event.
    func toDomain() -> Event {
        let mapped = MarketMapper.event(from: event)
        guard mapped.gameStartTime == nil, let kickoff = earliestKickoff else { return mapped }
        return Event(
            id: mapped.id,
            title: mapped.title,
            slug: mapped.slug,
            markets: mapped.markets,
            volume: mapped.volume,
            imageURL: mapped.imageURL,
            tags: mapped.tags,
            gameStartTime: kickoff,
            description: mapped.description
        )
    }
}
