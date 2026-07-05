import SwiftUI

/// Horizontally scrolling top-level category rail pinned under the top bar.
///
/// Renders one tappable "chip" per `ShellCategory` case (Trending, World Cup,
/// Breaking, Politics, Sports). Tapping a chip updates the `selected` binding,
/// which the parent view uses to switch which content feed is shown below.
public struct CategoryRail: View {
    /// The currently active category. Changing this from outside (e.g. via deep
    /// link) updates which chip is highlighted; tapping a chip updates this binding
    /// so the parent screen can react.
    @Binding private var selected: ShellCategory

    /// Creates the category rail.
    /// - Parameter selected: A binding to the currently selected category, shared
    ///   with the parent view that decides what content to show.
    public init(selected: Binding<ShellCategory>) {
        self._selected = selected
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 20) {
                ForEach(ShellCategory.allCases, id: \.self) { category in
                    chip(category)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    /// Builds a single tappable chip for one category, styled differently
    /// depending on whether it's the currently active one (bold text and the
    /// category's accent color vs. plain secondary text).
    /// - Parameter category: The category this chip represents.
    /// - Returns: A button that selects `category` when tapped.
    @ViewBuilder
    private func chip(_ category: ShellCategory) -> some View {
        let isActive = category == selected
        Button {
            selected = category
        } label: {
            HStack(spacing: 6) {
                if let glyph = category.glyph {
                    Image(systemName: glyph)
                }
                Text(category.title)
            }
            .font(DSFont.headline)
            .fontWeight(isActive ? .bold : .regular)
            .foregroundStyle(isActive ? category.activeColor : DSColor.textSecondary)
        }
        .buttonStyle(.plain)
    }
}
