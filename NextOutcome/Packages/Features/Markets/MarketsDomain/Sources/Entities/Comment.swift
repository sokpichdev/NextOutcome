//
//  Comment.swift
//  NextOutcome
//
//  Created by Sok Pich on 03/07/2026.
//

import Foundation

/// A user comment on an event's discussion thread.
public struct Comment: Identifiable, Hashable, Sendable {
    public let id: String
    public let authorName: String
    public let avatarURL: URL?
    public let createdAt: Date?
    public let body: String

    public init(id: String, authorName: String, avatarURL: URL?, createdAt: Date?, body: String) {
        self.id = id
        self.authorName = authorName
        self.avatarURL = avatarURL
        self.createdAt = createdAt
        self.body = body
    }
}
