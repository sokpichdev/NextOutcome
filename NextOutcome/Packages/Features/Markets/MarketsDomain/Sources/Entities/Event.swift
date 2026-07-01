//
//  Event.swift
//  NextOutcome
//
//  Created by Sok Pich on 30/06/2026.
//

import Foundation

public struct Event: Identifiable, Hashable {
    public let id: String
    public let title: String
    public let slug: String
    public let markets: [Market]
    public let volume: Decimal
    public let imageURL: URL?
    public let tags: [Tag]

    public init(
        id: String,
        title: String,
        slug: String,
        markets: [Market],
        volume: Decimal,
        imageURL: URL?,
        tags: [Tag] = []
    ) {
        self.id = id
        self.title = title
        self.slug = slug
        self.markets = markets
        self.volume = volume
        self.imageURL = imageURL
        self.tags = tags
    }
}
