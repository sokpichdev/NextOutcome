import SwiftUI

public struct SideMenuItem: Identifiable, Hashable {
    public let id: String
    public let title: String
    public let glyph: String?
    public init(id: String, title: String, glyph: String?) {
        self.id = id; self.title = title; self.glyph = glyph
    }
}

/// Left-slide drawer opened from the avatar. Presentational; parent owns the scrim/animation.
public struct SideMenuDrawer: View {
    public static let primaryItems: [SideMenuItem] = [
        .init(id: "leaderboard", title: "Leaderboard", glyph: "trophy"),
        .init(id: "rewards",     title: "Rewards",     glyph: "dollarsign.circle"),
        .init(id: "apis",        title: "APIs",        glyph: "cablecar")
    ]

    public static let secondaryItems: [SideMenuItem] = [
        .init(id: "accuracy",      title: "Accuracy",      glyph: nil),
        .init(id: "support",       title: "Support",       glyph: nil),
        .init(id: "status",        title: "Status",        glyph: nil),
        .init(id: "documentation", title: "Documentation", glyph: nil),
        .init(id: "help",          title: "Help Center",   glyph: nil),
        .init(id: "terms",         title: "Terms of Use",  glyph: nil)
    ]

    private let addressShort: String
    private let onSelect: (String) -> Void
    private let onLogout: () -> Void
    private let onSettings: () -> Void

    public init(
        addressShort: String,
        onSelect: @escaping (String) -> Void,
        onLogout: @escaping () -> Void = {},
        onSettings: @escaping () -> Void = {}
    ) {
        self.addressShort = addressShort
        self.onSelect = onSelect
        self.onLogout = onLogout
        self.onSettings = onSettings
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Group {
                ForEach(Self.primaryItems) { row($0) }
                Divider().overlay(DSColor.separator).padding(.vertical, 12)
                ForEach(Self.secondaryItems) { row($0) }
            }
            Spacer()
            Button(role: .destructive, action: onLogout) {
                Text("Logout")
                    .font(DSFont.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(DSColor.separator))
            }
        }
        .padding(20)
        .padding(.top, 44)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(DSColor.surface)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Circle().fill(DSGradient.accent).frame(width: 40, height: 40)
            Text(addressShort)
                .font(DSFont.headline)
                .foregroundStyle(DSColor.textPrimary)
            Spacer()
            Button(action: onSettings) {
                Image(systemName: "gearshape").foregroundStyle(DSColor.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.bottom, 24)
    }

    private func row(_ item: SideMenuItem) -> some View {
        Button { onSelect(item.id) } label: {
            HStack(spacing: 12) {
                if let glyph = item.glyph {
                    Image(systemName: glyph).frame(width: 24)
                }
                Text(item.title)
                Spacer()
            }
            .font(DSFont.body)
            .foregroundStyle(item.glyph == nil ? DSColor.textSecondary : DSColor.textPrimary)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }
}
