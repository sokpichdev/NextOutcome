import SwiftUI

/// Horizontally scrolling top-level category rail pinned under the top bar.
///
/// Renders one tappable "chip" per tab in `tabs` — the 5 pinned tabs (Trending, World
/// Cup, Breaking, Politics, Sports) plus any curated categories that have resolved to a
/// live tag id. Tapping a chip updates the `selected` binding, which the parent view
/// uses to switch which content feed is shown below.
public struct CategoryRail: View {
    /// The tabs to render, in order.
    private let tabs: [HubTab]
    /// The currently active tab. Changing this from outside (e.g. via deep link)
    /// updates which chip is highlighted; tapping a chip updates this binding so the
    /// parent screen can react.
    @Binding private var selected: HubTab

    /// Creates the category rail.
    /// - Parameters:
    ///   - tabs: The tabs to render, in order. Defaults to the 5 pinned tabs.
    ///   - selected: A binding to the currently selected tab, shared with the parent view
    ///     that decides what content to show.
    public init(tabs: [HubTab] = HubTab.pinned, selected: Binding<HubTab>) {
        self.tabs = tabs
        self._selected = selected
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 20) {
                ForEach(tabs) { tab in
                    chip(tab)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    /// Builds a single tappable chip for one tab, styled differently depending on
    /// whether it's the currently active one (bold text and the tab's accent color vs.
    /// plain secondary text).
    /// - Parameter tab: The tab this chip represents.
    /// - Returns: A button that selects `tab` when tapped.
    @ViewBuilder
    private func chip(_ tab: HubTab) -> some View {
        let isActive = tab == selected
        Button {
            selected = tab
        } label: {
            HStack(spacing: 6) {
                if let glyph = tab.glyph {
                    Image(systemName: glyph)
                }
                Text(tab.title)
            }
            .font(DSFont.headline)
            .fontWeight(isActive ? .bold : .regular)
            .foregroundStyle(isActive ? tab.activeColor : DSColor.textSecondary)
        }
        .buttonStyle(.plain)
    }
}
