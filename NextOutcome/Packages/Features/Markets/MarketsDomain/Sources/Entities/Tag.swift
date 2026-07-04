//
//  Tag.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

/// A category label used to filter events (e.g. "Politics", "Sports").
public struct Tag: Identifiable, Hashable {
    /// The tag's unique id.
    public let id: String
    /// The human-readable label shown in filter chips.
    public let label: String
    /// The tag's URL slug, used when querying by tag.
    public let slug: String

    /// Creates a tag.
    public init(id: String, label: String, slug: String) {
        self.id = id
        self.label = label
        self.slug = slug
    }
}
