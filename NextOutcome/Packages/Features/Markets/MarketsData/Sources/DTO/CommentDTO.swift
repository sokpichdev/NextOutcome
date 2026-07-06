//
//  CommentDTO.swift
//  NextOutcome
//
//  Created by Sok Pich on 03/07/2026.
//

import Foundation

/// Gamma `/comments?parent_entity_type=Event&parent_entity_id=<id>` row. Author fields
/// live under a nested `profile` object; both `profile` and its fields are frequently
/// absent (anonymous / deleted accounts), so decoding is deliberately tolerant.
struct CommentProfileDTO: Decodable {
    /// The author's display name, if any.
    let name: String?
    /// A generated pseudonym, used when `name` is absent.
    let pseudonym: String?
    /// The author's avatar URL string.
    let profileImage: String?
    /// The author's proxy (trading) wallet — the address `/positions?user=` expects, not
    /// the base `userAddress` on the comment itself.
    let proxyWallet: String?

    /// JSON keys for `CommentProfileDTO`.
    enum CodingKeys: String, CodingKey {
        case name, pseudonym, profileImage, proxyWallet
    }

    /// Tolerant decoder (all fields optional for anonymous/deleted accounts).
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try? c.decode(String.self, forKey: .name)
        pseudonym = try? c.decode(String.self, forKey: .pseudonym)
        profileImage = try? c.decode(String.self, forKey: .profileImage)
        proxyWallet = try? c.decode(String.self, forKey: .proxyWallet)
    }
}

/// Gamma comment row.
struct CommentDTO: Decodable {
    /// The comment id (a random UUID is synthesized if absent).
    let id: String
    /// The comment text.
    let body: String
    /// The created-at ISO string, if present.
    let createdAt: String?
    /// The nested author profile, if present.
    let profile: CommentProfileDTO?
    /// The number of reactions ("likes") on the comment.
    let reactionCount: Int

    /// JSON keys for `CommentDTO`.
    enum CodingKeys: String, CodingKey {
        case id, body, createdAt, profile, reactionCount
    }

    /// Tolerant decoder that never fails a row on missing fields.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        body = (try? c.decode(String.self, forKey: .body)) ?? ""
        createdAt = try? c.decode(String.self, forKey: .createdAt)
        profile = try? c.decode(CommentProfileDTO.self, forKey: .profile)
        reactionCount = (try? c.decode(Int.self, forKey: .reactionCount)) ?? 0
    }
}
