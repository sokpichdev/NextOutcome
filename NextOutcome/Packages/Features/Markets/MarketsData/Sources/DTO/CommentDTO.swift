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
    let name: String?
    let pseudonym: String?
    let profileImage: String?

    enum CodingKeys: String, CodingKey {
        case name, pseudonym, profileImage
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try? c.decode(String.self, forKey: .name)
        pseudonym = try? c.decode(String.self, forKey: .pseudonym)
        profileImage = try? c.decode(String.self, forKey: .profileImage)
    }
}

struct CommentDTO: Decodable {
    let id: String
    let body: String
    let createdAt: String?
    let profile: CommentProfileDTO?

    enum CodingKeys: String, CodingKey {
        case id, body, createdAt, profile
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        body = (try? c.decode(String.self, forKey: .body)) ?? ""
        createdAt = try? c.decode(String.self, forKey: .createdAt)
        profile = try? c.decode(CommentProfileDTO.self, forKey: .profile)
    }
}
