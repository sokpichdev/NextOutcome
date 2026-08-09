import SwiftUI

/// One tab in the home screen's top-level category rail.
///
/// The rail is **entirely server-driven**: its contents are the related tags of Gamma's
/// curated `top-navbar` tag, rendered in the server's rank order (see `HubTabsViewModel` in
/// MarketsPresentation, and `docs/polymarket-tag-navigation.md`). Nothing here enumerates the
/// live categories — the row is curated by Polymarket ops and changes without notice.
///
/// The statics below are **not** the rail. They're route identifiers: `RootView` compares the
/// selected tab against them to decide which screen to show. Because equality is id-only, a tab
/// built from a fetched tag matches the matching static automatically.
public struct HubTab: Identifiable, @unchecked Sendable {
    /// Stable identity used for selection/highlighting and equality — always the Gamma tag
    /// slug, so a fetched tab and a hardcoded route identifier compare equal.
    public let id: String
    /// The human-readable label shown on the chip for this category.
    public let title: String
    /// Leading SF Symbol; `nil` when the chip is text-only.
    public let glyph: String?
    /// Text/glyph color when this chip is the active one.
    public let activeColor: Color
    /// The Gamma tag id sent to the API when this tab is selected, or `nil` for "no filter".
    ///
    /// `nil` is load-bearing for `.all`: Gamma really does have an `all` tag (id `100215`),
    /// but filtering by it returns the couple of events tagged *literally* "all", not the
    /// whole feed. The default tab must therefore send no tag at all.
    public let tagID: String?

    /// Creates a hub tab.
    public init(id: String, title: String, glyph: String?, activeColor: Color, tagID: String?) {
        self.id = id
        self.title = title
        self.glyph = glyph
        self.activeColor = activeColor
        self.tagID = tagID
    }

    /// The unfiltered default feed. Selected on launch; sends no tag filter.
    public static let all = HubTab(id: "all", title: "All", glyph: nil, activeColor: DSColor.accent, tagID: nil)

    // MARK: - Route identifiers
    //
    // These exist so `RootView` can ask "is the selected category the one that has a bespoke
    // hub screen?" They are matched by slug against whatever the rail fetched, so their
    // `title`/`glyph`/`tagID` are never rendered — with one exception: `esports` is *injected*
    // into the rail by `HubTabsViewModel`, so its title and tagID are rendered and queried.
    //
    // Polymarket's nav does not currently include `world-cup`, so that screen is unreachable
    // from the rail today — the branch is kept because it lights up again the moment the tag
    // returns.

    /// The World Cup hub — brackets, schedules, and props for the tournament.
    public static let worldCup = HubTab(id: "world-cup", title: "World Cup", glyph: "soccerball", activeColor: DSColor.categoryGold, tagID: "519")
    /// The Esports hub — live matches, streams, and the esports leaderboard.
    ///
    /// Unlike the other identifiers here this one is also *rendered*. Gamma's `top-navbar` row
    /// omits `esports`, yet polymarket.com shows an Esports entry: their web client injects it
    /// (and `Art`) client-side on top of the same fetched row. `HubTabsViewModel` does the
    /// same, which is why `title` and `tagID` below have to be right.
    ///
    /// `64` is the `esports` tag. Not `100639` — that is the broader `games` tag.
    public static let esports = HubTab(id: "esports", title: "Esports", glyph: nil, activeColor: DSColor.textPrimary, tagID: "64")
    /// Breaking news markets. Also reachable from its own bottom tab.
    public static let breaking = HubTab(id: "breaking", title: "Breaking", glyph: nil, activeColor: DSColor.textPrimary, tagID: "198")
    /// Political markets (elections, policy outcomes, etc.).
    public static let politics = HubTab(id: "politics", title: "Politics", glyph: nil, activeColor: DSColor.textPrimary, tagID: "2")
    /// General sports markets (outside the dedicated World Cup hub).
    public static let sports = HubTab(id: "sports", title: "Sports", glyph: nil, activeColor: DSColor.textPrimary, tagID: "1")

    /// The rail shown before the live nav arrives, and if fetching it fails.
    ///
    /// A snapshot of Gamma's `top-navbar` row taken 2026-08-01 — deliberately *not* a source of
    /// truth. It exists only so the rail is never empty on a cold or offline launch; the fetched
    /// row replaces it wholesale within a second of launch. Expect it to drift, and don't fix it
    /// unless the offline experience is visibly wrong.
    ///
    /// `.esports` is the one entry that is *not* from that snapshot: it's app-owned and injected
    /// into the live row too, so it has to be here or it would vanish offline. See `.esports`.
    public static let fallbackNav: [HubTab] = [
        .all,
        HubTab(id: "politics",    title: "Politics",    glyph: nil, activeColor: DSColor.textPrimary, tagID: "2"),
        HubTab(id: "sports",      title: "Sports",      glyph: nil, activeColor: DSColor.textPrimary, tagID: "1"),
        HubTab(id: "crypto",      title: "Crypto",      glyph: nil, activeColor: DSColor.textPrimary, tagID: "21"),
        .esports,
        HubTab(id: "finance",     title: "Finance",     glyph: nil, activeColor: DSColor.textPrimary, tagID: "120"),
        HubTab(id: "geopolitics", title: "Geopolitics", glyph: nil, activeColor: DSColor.textPrimary, tagID: "100265"),
        HubTab(id: "tech",        title: "Tech",        glyph: nil, activeColor: DSColor.textPrimary, tagID: "1401"),
        HubTab(id: "pop-culture", title: "Culture",     glyph: nil, activeColor: DSColor.textPrimary, tagID: "596"),
        HubTab(id: "economy",     title: "Economy",     glyph: nil, activeColor: DSColor.textPrimary, tagID: "100328"),
        HubTab(id: "weather",     title: "Weather",     glyph: nil, activeColor: DSColor.textPrimary, tagID: "84"),
        HubTab(id: "elections",   title: "Elections",   glyph: nil, activeColor: DSColor.textPrimary, tagID: "144"),
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
