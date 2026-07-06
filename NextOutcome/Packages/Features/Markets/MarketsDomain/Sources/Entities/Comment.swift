//
//  Comment.swift
//  NextOutcome
//
//  Created by Sok Pich on 03/07/2026.
//

import Foundation

/// A user comment on an event's discussion thread.
public struct Comment: Identifiable, Hashable, Sendable {
    /// Stable identity for the comment.
    public let id: String
    /// The commenter's display name.
    public let authorName: String
    /// The commenter's avatar image, if any.
    public let avatarURL: URL?
    /// When the comment was posted, if known.
    public let createdAt: Date?
    /// The comment text.
    public let body: String
    /// The number of reactions ("likes") on the comment.
    public let likeCount: Int
    /// The commenter's proxy (trading) wallet, used to look up their positions in this
    /// event for the holder badge. `nil` for anonymous/deleted accounts.
    public let proxyWallet: String?

    /// Creates a comment.
    public init(id: String, authorName: String, avatarURL: URL?, createdAt: Date?, body: String, likeCount: Int = 0, proxyWallet: String? = nil) {
        self.id = id
        self.authorName = authorName
        self.avatarURL = avatarURL
        self.createdAt = createdAt
        self.body = body
        self.likeCount = likeCount
        self.proxyWallet = proxyWallet
    }
}
