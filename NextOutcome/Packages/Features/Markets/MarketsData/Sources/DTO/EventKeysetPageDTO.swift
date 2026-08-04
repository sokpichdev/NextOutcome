//
//  EventKeysetPageDTO.swift
//  NextOutcome
//
//  Created by Sok Pich on 03/08/2026.
//
import Foundation

/// One page from a Gamma keyset (cursor) endpoint — `/events/keyset` and friends.
///
/// Unlike the bare `/events` array, keyset endpoints wrap their rows in an envelope and
/// return an opaque `next_cursor` to feed back as `after_cursor`. They reject `offset`
/// outright (HTTP 422, `"offset is not allowed on keyset endpoints"`), which is why the
/// cursor is the only way to page them.
///
/// A `nil`/absent `next_cursor` means the last page.
struct EventKeysetPageDTO: Decodable {
    /// The events on this page.
    let events: [EventDTO]
    /// The opaque cursor for the next page, or `nil` at the end of the list.
    let nextCursor: String?

    /// JSON keys — Gamma uses snake_case for the cursor here, unlike most of its payloads.
    enum CodingKeys: String, CodingKey {
        case events
        case nextCursor = "next_cursor"
    }

    /// Tolerant decoder: a missing `events` array degrades to an empty page rather than
    /// failing the request, matching the DTO conventions elsewhere in this layer.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        events = (try? c.decode([EventDTO].self, forKey: .events)) ?? []
        nextCursor = try? c.decode(String.self, forKey: .nextCursor)
    }
}
