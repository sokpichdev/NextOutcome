//
//  Tag.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

public struct Tag: Identifiable, Hashable {
    public let id: String
    public let label: String
    public let slug: String

    public init(id: String, label: String, slug: String) {
        self.id = id
        self.label = label
        self.slug = slug
    }
}
