import SwiftUI

/// Horizontally scrolling top-level category rail pinned under the top bar.
public struct CategoryRail: View {
    @Binding private var selected: ShellCategory

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
