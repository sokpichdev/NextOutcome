import SwiftUI

/// Horizontally scrolling row of capsule filter chips; selected chip filled with the accent token.
public struct ChipRow: View {
    private let items: [String]
    @Binding private var selection: Int

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
