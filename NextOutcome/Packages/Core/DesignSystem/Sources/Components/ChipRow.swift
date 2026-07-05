import SwiftUI

/// Horizontally scrolling row of capsule filter chips; selected chip filled with the accent token.
///
/// Unlike `DSChip` (a single standalone chip), `ChipRow` manages a whole set of
/// mutually-exclusive options and tracks which one is selected via an `Int` index
/// binding — handy for simple string-based filter rows (e.g. timeframes, sort options).
public struct ChipRow: View {
    /// The chip labels to display, in order.
    private let items: [String]
    /// The index into `items` of the currently selected chip. Tapping a chip
    /// updates this binding so the parent can react to the selection.
    @Binding private var selection: Int

    /// Creates a chip row.
    /// - Parameters:
    ///   - items: The chip labels to display.
    ///   - selection: A binding to the selected index within `items`.
    public init(items: [String], selection: Binding<Int>) {
        self.items = items
        self._selection = selection
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DSLayout.spacingSmall) {
                ForEach(items.indices, id: \.self) { index in
                    chip(for: index)
                }
            }
            .padding(.horizontal, DSLayout.margin)
        }
    }

    /// Builds a single chip for the item at `index`, styled as selected (accent
    /// fill, white text) or unselected (surface fill, secondary text).
    /// - Parameter index: The index of the item within `items` to render.
    /// - Returns: A button that sets `selection` to `index` when tapped.
    private func chip(for index: Int) -> some View {
        let isSelected = selection == index
        return Button {
            selection = index
        } label: {
            Text(items[index])
                .font(DSFont.caption.bold())
                .foregroundStyle(isSelected ? .white : DSColor.textSecondary)
                .padding(.horizontal, DSLayout.spacingMedium)
                .padding(.vertical, DSLayout.spacingXSmall)
                .background(isSelected ? DSColor.accent : DSColor.surface)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
