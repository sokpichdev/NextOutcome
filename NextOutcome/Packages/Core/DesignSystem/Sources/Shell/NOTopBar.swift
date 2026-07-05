import SwiftUI

/// Persistent top app bar: NextOutcome wordmark left; gift, bell, avatar-orb right.
///
/// Shown at the top of most screens via `ShellChrome`. Provides three tappable
/// icons on the right (gift/rewards, notifications, account menu) via closures the
/// caller supplies, so this view stays free of navigation logic — it just reports
/// "the user tapped X" and lets the parent decide what happens.
public struct NOTopBar: View {
    /// Called when the gift/rewards icon is tapped.
    private let onGift: () -> Void
    /// Called when the bell/notifications icon is tapped.
    private let onBell: () -> Void
    /// Called when the circular avatar icon is tapped (typically opens the account menu).
    private let onAvatar: () -> Void

    /// Creates the top bar.
    /// - Parameters:
    ///   - onGift: Action to run when the gift icon is tapped. Defaults to a no-op.
    ///   - onBell: Action to run when the bell icon is tapped. Defaults to a no-op.
    ///   - onAvatar: Action to run when the avatar icon is tapped. Defaults to a no-op.
    public init(
        onGift: @escaping () -> Void = {},
        onBell: @escaping () -> Void = {},
        onAvatar: @escaping () -> Void = {}
    ) {
        self.onGift = onGift
        self.onBell = onBell
        self.onAvatar = onAvatar
    }

    public var body: some View {
        HStack(spacing: DSLayout.margin) {
            HStack(spacing: DSLayout.spacingSmall) {
                Image(systemName: "chart.bar.doc.horizontal")
                    .foregroundStyle(DSColor.textPrimary)
                Text("NextOutcome")
                    .font(DSFont.title)
                    .foregroundStyle(DSColor.textPrimary)
            }
            Spacer()
            Button(action: onGift) {
                Image(systemName: "gift").foregroundStyle(DSColor.textSecondary)
            }
            .accessibilityLabel("Rewards")
            Button(action: onBell) {
                Image(systemName: "bell").foregroundStyle(DSColor.textSecondary)
            }
            .accessibilityLabel("Notifications")
            Button(action: onAvatar) {
                Circle()
                    .fill(DSGradient.accent)
                    .frame(width: 32, height: 32)
                    .glowAccent(radius: 6)
            }
            .accessibilityLabel("Account menu")
        }
        .buttonStyle(.plain)
        .font(DSFont.title3)
        .padding(.horizontal, DSLayout.margin)
        .padding(.vertical, DSLayout.spacingSmall)
    }
}
