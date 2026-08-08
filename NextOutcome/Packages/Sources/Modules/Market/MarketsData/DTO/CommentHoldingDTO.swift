//
//  CommentHoldingDTO.swift
//  NextOutcome
//

import Foundation

/// Data API `/positions?user=<wallet>&eventId=<id>` row: one of a user's positions in an
/// event, used for the comment "holder" badge.
struct CommentHoldingDTO: Decodable {
    /// The market's condition id.
    let conditionId: String
    /// Which side of the market is held ("Yes"/"No").
    let outcome: String
    /// The number of shares held.
    let size: Decimal

    /// JSON keys for `CommentHoldingDTO`.
    enum CodingKeys: String, CodingKey {
        case conditionId, outcome, size
    }

    /// Tolerant decoder — a row missing its size/outcome is dropped by the mapper rather
    /// than failing the whole batch.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        conditionId = (try? c.decode(String.self, forKey: .conditionId)) ?? ""
        outcome = (try? c.decode(String.self, forKey: .outcome)) ?? ""
        size = DTODecoding.decimal(c, .size)
    }
}
