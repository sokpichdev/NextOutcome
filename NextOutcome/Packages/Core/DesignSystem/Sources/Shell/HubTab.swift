import SwiftUI

/// One tab in the home screen's top-level category rail.
///
/// Five are "pinned": always present, in this fixed order, with their Gamma tag id
/// verified once via `gamma /tags/slug/<slug>` and hardcoded (world-cup=519,
/// breaking-news=198, politics=2, sports=1). The rest are resolved at runtime from
/// `curatedAdditional` — an app-owned, ordered list of categories (mirroring
/// Polymarket's web categories) whose tag id isn't hardcoded here, because there's no
/// API that hands back "the current nav categories"; each is looked up by slug once
/// per app session (see `HubTabsViewModel` in MarketsPresentation).
public struct HubTab: Identifiable, @unchecked Sendable {
    /// Stable identity used for selection/highlighting and equality. Pinned tabs use a
    /// fixed string; dynamic tabs use their Gamma tag slug.
    public let id: String
    /// The human-readable label shown on the chip for this category.
    public let title: String
    /// Leading SF Symbol; `nil` when the chip is text-only.
    public let glyph: String?
    /// Text/glyph color when this chip is the active one.
    public let activeColor: Color
    /// The Gamma tag id sent to the API when this tab is selected. `nil` only for
    /// `.trending`, which means "no filter."
    public let tagID: String?

    /// Creates a hub tab.
    public init(id: String, title: String, glyph: String?, activeColor: Color, tagID: String?) {
        self.id = id
        self.title = title
        self.glyph = glyph
        self.activeColor = activeColor
        self.tagID = tagID
    }

    /// The default "what's popular right now" feed.
    public static let trending = HubTab(id: "trending", title: "Trending", glyph: "chart.line.uptrend.xyaxis", activeColor: DSColor.accent, tagID: nil)
    /// The World Cup hub — brackets, schedules, and props for the tournament.
    public static let worldCup = HubTab(id: "world-cup", title: "World Cup", glyph: "soccerball", activeColor: DSColor.categoryGold, tagID: "519")
    /// Breaking news markets.
    public static let breaking = HubTab(id: "breaking", title: "Breaking", glyph: nil, activeColor: DSColor.textPrimary, tagID: "198")
    /// Political markets (elections, policy outcomes, etc.).
    public static let politics = HubTab(id: "politics", title: "Politics", glyph: nil, activeColor: DSColor.textPrimary, tagID: "2")
    /// General sports markets (outside the dedicated World Cup hub).
    public static let sports = HubTab(id: "sports", title: "Sports", glyph: nil, activeColor: DSColor.textPrimary, tagID: "1")

    /// The 5 always-present tabs, in the rail's fixed leading order.
    public static let pinned: [HubTab] = [.trending, .worldCup, .breaking, .politics, .sports]

    /// An additional home-rail category, resolved at runtime from its Gamma tag slug.
    public struct CuratedAdditional: Sendable {
        /// The Gamma tag slug to resolve via `GET /tags/slug/{slug}`.
        public let slug: String
        /// The chip's label once resolved.
        public let title: String
        /// Leading SF Symbol for the resolved chip; `nil` for a text-only chip.
        public let glyph: String?

        /// Creates a curated-additional category descriptor.
        public init(slug: String, title: String, glyph: String?) {
            self.slug = slug
            self.title = title
            self.glyph = glyph
        }
    }

    /// Categories shown after the pinned 5, in this order, once each slug resolves to a
    /// live Gamma tag id. Slugs verified via `gamma /tags/slug/<slug>` on 2026-07-10.
    /// "Mentions" (from the web categories list) has no corresponding Gamma tag and is
    /// intentionally omitted.
    public static let curatedAdditional: [CuratedAdditional] = [
        CuratedAdditional(slug: "crypto", title: "Crypto", glyph: "bitcoinsign.circle"),
        CuratedAdditional(slug: "esports", title: "Esports", glyph: "gamecontroller.fill"),
        CuratedAdditional(slug: "finance", title: "Finance", glyph: "dollarsign.circle"),
        CuratedAdditional(slug: "geopolitics", title: "Geopolitics", glyph: "globe.americas.fill"),
        CuratedAdditional(slug: "tech", title: "Tech", glyph: "cpu"),
        CuratedAdditional(slug: "pop-culture", title: "Culture", glyph: "theatermasks.fill"),
        CuratedAdditional(slug: "economy", title: "Economy", glyph: "chart.bar.xaxis"),
        CuratedAdditional(slug: "weather", title: "Weather", glyph: "cloud.sun.fill"),
        CuratedAdditional(slug: "election", title: "Election", glyph: "checkmark.seal.fill"),
        CuratedAdditional(slug: "art", title: "Art", glyph: "paintpalette.fill"),
        CuratedAdditional(slug: "iran", title: "Iran", glyph: nil),
    ]
}

extension HubTab: Equatable {
    /// Two tabs are equal iff their `id` matches — title/glyph/color/tagID never differ
    /// for the same id in practice, and comparing by id keeps `Set`/`==` cheap and matches
    /// the "is this the selected tab" intent used throughout the rail.
    public static func == (lhs: HubTab, rhs: HubTab) -> Bool { lhs.id == rhs.id }
}

extension HubTab: Hashable {
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
