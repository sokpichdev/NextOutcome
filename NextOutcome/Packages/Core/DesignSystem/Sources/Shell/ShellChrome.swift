import SwiftUI

/// Wraps a tab-root's scroll content with the persistent top bar + category rail
/// over the accent-glow background. Market-detail pushes do NOT use this.
public struct ShellChrome<Content: View>: View {
    @Binding private var selectedCategory: ShellCategory
    private let onGift: () -> Void
    private let onBell: () -> Void
    private let onAvatar: () -> Void
    private let content: Content

    public init(
        selectedCategory: Binding<ShellCategory>,
        onGift: @escaping () -> Void = {},
        onBell: @escaping () -> Void = {},
        onAvatar: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self._selectedCategory = selectedCategory
        self.onGift = onGift
        self.onBell = onBell
        self.onAvatar = onAvatar
        self.content = content()
    }

    public var body: some View {
        AccentGlowBackground {
            VStack(spacing: 0) {
                NOTopBar(onGift: onGift, onBell: onBell, onAvatar: onAvatar)
                CategoryRail(selected: $selectedCategory)
                Divider().overlay(DSColor.separator)
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
