import Foundation
import MarketsDomain
import DesignSystem

/// Drives the home rail's tab list.
///
/// The rail is whatever Gamma's curated `top-navbar` tag says it is: one request returns every
/// category's id, label and rank together. Until that lands — and if it fails — the rail shows
/// `HubTab.fallbackNav` so it's never empty.
@MainActor
@Observable
public final class HubTabsViewModel {
    /// The Gamma tag whose related tags *are* the top navigation row. Found in Polymarket's own
    /// React Query keys; there is a real tag at this slug labelled "Top Navbar".
    private static let navigationRowSlug = "top-navbar"

    /// The slug of the tag that means "everything". It exists as a real tag, but filtering by
    /// it returns only the handful of events literally tagged "all" — so its tab sends no
    /// filter at all. See `HubTab.tagID`.
    private static let unfilteredSlug = "all"

    /// The tabs to render in the rail, in order. Starts as the offline fallback and is replaced
    /// wholesale once `loadDynamicTabsIfNeeded()` resolves.
    public private(set) var tabs: [HubTab] = HubTab.fallbackNav

    private let fetchRelatedTags: FetchRelatedTagsUseCase
    private var hasLoadedDynamicTabs = false

    /// Creates the view model.
    /// - Parameter fetchRelatedTags: Fetches a navigation row by its tag slug.
    public init(fetchRelatedTags: FetchRelatedTagsUseCase) {
        self.fetchRelatedTags = fetchRelatedTags
    }

    /// Replaces the rail with the live navigation row, in the server's rank order.
    ///
    /// Best-effort: on failure — or if the row comes back empty, which would blank the rail —
    /// the fallback stays and no error is surfaced. Idempotent and safe to call from `.task` on
    /// every appearance; only the first call fetches.
    public func loadDynamicTabsIfNeeded() async {
        guard !hasLoadedDynamicTabs else { return }
        hasLoadedDynamicTabs = true

        guard let tags = try? await fetchRelatedTags.execute(slug: Self.navigationRowSlug),
              !tags.isEmpty
        else { return }

        tabs = tags.map { tag in
            HubTab(
                id: tag.slug,
                title: tag.label,
                glyph: nil,
                activeColor: DSColor.textPrimary,
                tagID: tag.slug == Self.unfilteredSlug ? nil : tag.id
            )
        }
    }
}
