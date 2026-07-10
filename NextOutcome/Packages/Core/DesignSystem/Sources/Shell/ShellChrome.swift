import SwiftUI

/// Wraps a tab-root's scroll content with the persistent top bar + category rail
/// over the accent-glow background. Market-detail pushes do NOT use this.
///
/// This is the standard "frame" used by each top-level tab screen (Home, World
/// Cup hub, etc.): it stacks the glowing background, the `NOTopBar`, the
/// `CategoryRail`, a divider, and finally the caller's own scrollable content.
/// Screens reached by pushing into a detail (e.g. an individual market's page)
/// skip this wrapper since they don't need the category rail.
public struct ShellChrome<Content: View>: View {
    /// The tabs to show in the category rail. Only the Home tab passes anything other
    /// than the default — see `HubTabsViewModel`.
    private let tabs: [HubTab]
    /// The currently selected top-level tab, shown highlighted in the category rail and
    /// shared with the parent to filter content.
    @Binding private var selectedCategory: HubTab
    /// Whether the category rail (Trending/World Cup/Breaking/…) is shown below the top bar.
    /// Only the Home tab has content that responds to it — other tabs hide it.
    private let showsCategoryRail: Bool
    /// Forwarded to `NOTopBar`'s gift icon action.
    private let onGift: () -> Void
    /// Forwarded to `NOTopBar`'s bell/notifications icon action.
    private let onBell: () -> Void
    /// Forwarded to `NOTopBar`'s avatar/account icon action.
    private let onAvatar: () -> Void
    /// The tab's own scrollable content, rendered below the top bar and category rail.
    private let content: Content

    /// Creates the shell chrome wrapper around a tab's content.
    /// - Parameters:
    ///   - tabs: The tabs to show in the category rail. Defaults to the 5 pinned tabs.
    ///   - selectedCategory: Binding to the active top-level tab.
    ///   - showsCategoryRail: Whether to show the category rail below the top bar. Defaults
    ///     to `true`; pass `false` for tabs whose content doesn't filter by category.
    ///   - onGift: Action for the gift icon. Defaults to a no-op.
    ///   - onBell: Action for the bell icon. Defaults to a no-op.
    ///   - onAvatar: Action for the avatar icon (required — typically opens the account menu/drawer).
    ///   - content: A view builder producing the tab's main content.
    public init(
        tabs: [HubTab] = HubTab.pinned,
        selectedCategory: Binding<HubTab>,
        showsCategoryRail: Bool = true,
        onGift: @escaping () -> Void = {},
        onBell: @escaping () -> Void = {},
        onAvatar: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.tabs = tabs
        self._selectedCategory = selectedCategory
        self.showsCategoryRail = showsCategoryRail
        self.onGift = onGift
        self.onBell = onBell
        self.onAvatar = onAvatar
        self.content = content()
    }

    public var body: some View {
        AccentGlowBackground {
            VStack(spacing: 0) {
                NOTopBar(onGift: onGift, onBell: onBell, onAvatar: onAvatar)
                if showsCategoryRail {
                    CategoryRail(tabs: tabs, selected: $selectedCategory)
                    Divider().overlay(DSColor.separator)
                }
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
