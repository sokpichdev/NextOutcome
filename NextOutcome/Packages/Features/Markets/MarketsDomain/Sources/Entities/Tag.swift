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
    /// How many live events carry this tag, when the source endpoint reports it.
    ///
    /// `nil` means "unknown", not "zero" — only the related-tags endpoint returns a count.
    /// The navigation rows drop tags whose count is `0`, because Gamma keeps dead tags in the
    /// payload regardless of the `status` query parameter.
    public let activeEventsCount: Int?

    /// Creates a tag.
    public init(id: String, label: String, slug: String, activeEventsCount: Int? = nil) {
        self.id = id
        self.label = label
        self.slug = slug
        self.activeEventsCount = activeEventsCount
    }
}
