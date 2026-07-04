import SwiftUI

/// A single tappable row in the side menu drawer (e.g. "Leaderboard", "Support").
public struct SideMenuItem: Identifiable, Hashable {
    /// A stable string identifier for this item, passed back through
    /// `SideMenuDrawer`'s `onSelect` closure so the parent knows which row was tapped.
    public let id: String
    /// The display label shown for this row.
    public let title: String
    /// The SF Symbol name shown leading the title, or `nil` for text-only rows
    /// (used for the drawer's secondary/legal-style links).
    public let glyph: String?
    /// Creates a side menu item.
    /// - Parameters:
    ///   - id: A stable identifier for this row.
    ///   - title: The label to display.
    ///   - glyph: An optional SF Symbol name to show before the title.
    public init(id: String, title: String, glyph: String?) {
        self.id = id; self.title = title; self.glyph = glyph
    }
}

/// Left-slide drawer opened from the avatar. Presentational; parent owns the scrim/animation.
///
/// This view only renders the drawer's *contents* (the menu rows, header, and
/// logout button) — it doesn't handle the slide-in animation or the dimmed
/// background overlay ("scrim") behind it. The parent screen is responsible for
/// showing/hiding this view and animating its position, typically via an
/// `.offset` or `.overlay` combined with a tap-to-dismiss scrim.
public struct SideMenuDrawer: View {
    /// The main navigation items shown at the top of the drawer (Leaderboard,
    /// Rewards, APIs), each with an icon.
    public static let primaryItems: [SideMenuItem] = [
        .init(id: "leaderboard", title: "Leaderboard", glyph: "trophy"),
        .init(id: "rewards",     title: "Rewards",     glyph: "dollarsign.circle"),
        .init(id: "apis",        title: "APIs",        glyph: "cablecar")
    ]

    /// Secondary, text-only links shown below a divider (Accuracy, Support,
    /// Status, Documentation, Help Center, Terms of Use).
    public static let secondaryItems: [SideMenuItem] = [
        .init(id: "accuracy",      title: "Accuracy",      glyph: nil),
        .init(id: "support",       title: "Support",       glyph: nil),
        .init(id: "status",        title: "Status",        glyph: nil),
        .init(id: "documentation", title: "Documentation", glyph: nil),
        .init(id: "help",          title: "Help Center",   glyph: nil),
        .init(id: "terms",         title: "Terms of Use",  glyph: nil)
    ]

    /// The shortened wallet address shown in the drawer header (e.g. "0xAbC1234…").
    private let addressShort: String
    /// Called with an item's `id` when the user taps a primary or secondary row.
    private let onSelect: (String) -> Void
    /// Called when the user taps the "Logout" button at the bottom.
    private let onLogout: () -> Void
    /// Called when the user taps the gear/settings icon in the header.
    private let onSettings: () -> Void

    /// Creates the side menu drawer.
    /// - Parameters:
    ///   - addressShort: The already-shortened wallet address to display in the header.
    ///   - onSelect: Called with the tapped item's `id` when a menu row is selected.
    ///   - onLogout: Action to run when "Logout" is tapped. Defaults to a no-op.
    ///   - onSettings: Action to run when the settings gear is tapped. Defaults to a no-op.
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
        .safeAreaPadding(.top)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(DSColor.surface)
    }

    /// The drawer's top section: a circular avatar placeholder, the shortened
    /// wallet address, and a settings gear icon.
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

    /// Builds a single tappable row for a menu item. Text-only items (no `glyph`)
    /// are styled with secondary/dimmer text color to visually distinguish them
    /// from the primary, icon-led items.
    /// - Parameter item: The menu item to render.
    /// - Returns: A button that calls `onSelect(item.id)` when tapped.
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
