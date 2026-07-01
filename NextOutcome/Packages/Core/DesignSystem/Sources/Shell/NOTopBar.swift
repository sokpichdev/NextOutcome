import SwiftUI

/// Persistent top app bar: NextOutcome wordmark left; gift, bell, avatar-orb right.
public struct NOTopBar: View {
    private let onGift: () -> Void
    private let onBell: () -> Void
    private let onAvatar: () -> Void

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
        HStack(spacing: 16) {
            HStack(spacing: 8) {
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
        .font(.title3)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}
