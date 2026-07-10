import Foundation
import MarketsDomain
import DesignSystem

/// Drives the home rail's tab list: the 5 pinned tabs are available immediately;
/// `loadDynamicTabsIfNeeded()` resolves the curated additional categories (Crypto,
/// Esports, ...) to their live Gamma tag ids and appends them afterward.
@MainActor
@Observable
public final class HubTabsViewModel {
    /// The tabs to render in the rail, in order. Starts as just the pinned 5; grows once
    /// `loadDynamicTabsIfNeeded()` resolves.
    public private(set) var tabs: [HubTab] = HubTab.pinned

    private let fetchTag: FetchTagUseCase
    private var hasLoadedDynamicTabs = false

    /// Creates the view model.
    /// - Parameter fetchTag: Resolves a curated category's slug to its live tag id.
    public init(fetchTag: FetchTagUseCase) {
        self.fetchTag = fetchTag
    }

    /// Resolves `HubTab.curatedAdditional` to live tag ids and appends the ones that
    /// succeed, in their curated order, after the pinned tabs. Best-effort: any slug that
    /// fails to resolve (network error, or the slug no longer exists) is silently skipped
    /// — no error is surfaced, the rail just doesn't grow that entry. Idempotent and safe
    /// to call from `.task` on every appearance; only the first call does any fetching.
    public func loadDynamicTabsIfNeeded() async {
        guard !hasLoadedDynamicTabs else { return }
        hasLoadedDynamicTabs = true

        let curated = HubTab.curatedAdditional
        let resolved: [Int: HubTab] = await withTaskGroup(of: (Int, HubTab?).self) { group in
            for (index, category) in curated.enumerated() {
                group.addTask { [fetchTag] in
                    guard let tag = try? await fetchTag.execute(slug: category.slug) else {
                        return (index, nil)
                    }
                    let resolvedTab = HubTab(
                        id: category.slug,
                        title: category.title,
                        glyph: category.glyph,
                        activeColor: DSColor.textPrimary,
                        tagID: tag.id
                    )
                    return (index, resolvedTab)
                }
            }
            var results: [Int: HubTab] = [:]
            for await (index, tab) in group {
                if let tab { results[index] = tab }
            }
            return results
        }

        let dynamicTabs = curated.indices.compactMap { resolved[$0] }
        tabs = HubTab.pinned + dynamicTabs
    }
}
