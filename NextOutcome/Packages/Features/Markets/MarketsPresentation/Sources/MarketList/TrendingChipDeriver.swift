//
//  TrendingChipDeriver.swift
//  NextOutcome
//
//  Created by Sok Pich on 04/07/2026.
//

import MarketsDomain

/// Derives the Trending sub-filter chips from the tags of a loaded page of events.
///
/// Gamma's carousel-tags endpoint (`/tags?is_carousel=true`) returns almost nothing and
/// `/tags/{id}/related-tags` is empty for the rail categories, so the chip row is built
/// client-side: rank tags by how many of the visible events carry them.
public enum TrendingChipDeriver {
    /// Tags that duplicate the category rail or carry no filtering value, matched against
    /// lowercased slug *and* label.
    public static let defaultExclusions: Set<String> = [
        "all", "trending", "recurring", "hide from new",
        "sports", "politics", "breaking", "breaking news", "world cup"
    ]

    /// Frequency-ranked tags across `events`, excluding generic tags, capped at `max`.
    ///
    /// Tags carried by fewer than `minCount` events are dropped to avoid one-off noise,
    /// unless that leaves fewer than 4 chips (a single 20-event page can be thin), in which
    /// case the unfiltered ranking is used.
    public static func chips(
        from events: [Event],
        excluding: Set<String> = defaultExclusions,
        minCount: Int = 2,
        max maxCount: Int = 8
    ) -> [Tag] {
        var counts: [String: (tag: Tag, count: Int)] = [:]
        for tag in events.flatMap(\.tags) {
            guard !excluding.contains(tag.slug.lowercased()),
                  !excluding.contains(tag.label.lowercased()) else { continue }
            counts[tag.id, default: (tag, 0)].count += 1
        }

        let ranked = counts.values.sorted {
            $0.count != $1.count ? $0.count > $1.count : $0.tag.label < $1.tag.label
        }
        let frequent = ranked.filter { $0.count >= minCount }
        let effective = frequent.count >= 4 ? frequent : ranked
        return effective.prefix(maxCount).map(\.tag)
    }
}
