import SwiftUI

/// What to display in the center of a `DetailHeader`.
public enum DetailHeaderTitle {
    /// A title with an optional leading icon image, e.g. a market's title with
    /// its category icon loaded from a URL.
    /// - Parameters:
    ///   - String: The title text.
    ///   - iconURL: An optional URL for a small icon to show before the title,
    ///     or `nil` to show no icon.
    case text(String, iconURL: URL?)
    /// A smaller, secondary-styled breadcrumb-style label instead of a full title
    /// (e.g. a parent event's name shown above a market detail page).
    case breadcrumb(String)
}

/// The set of trailing action buttons a `DetailHeader` can show (embed/code,
/// bookmark, share link). Conforms to `OptionSet` so callers can combine any
/// subset, e.g. `[.bookmark, .link]`.
public struct DetailHeaderActions: OptionSet {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    /// Shows an "embed"/code icon button (e.g. for embedding a chart elsewhere).
    public static let code     = DetailHeaderActions(rawValue: 1 << 0)
    /// Shows a bookmark/save icon button.
    public static let bookmark = DetailHeaderActions(rawValue: 1 << 1)
    /// Shows a share-link icon button.
    public static let link     = DetailHeaderActions(rawValue: 1 << 2)
    /// Shows a "Rules" text button (opens the rules bottom sheet).
    public static let rules    = DetailHeaderActions(rawValue: 1 << 3)
    /// Shows a discussion/comment-bubble icon button (opens the Comments/Top
    /// Holders/Positions/Activity bottom sheet).
    public static let discuss  = DetailHeaderActions(rawValue: 1 << 4)
}

/// Custom back-button header for pushed detail screens (native nav bar hidden).
///
/// Used at the top of pushed detail screens (event/market detail pages) instead
/// of the system navigation bar, so the back button, title, and trailing action
/// icons can be styled to match the app's dark theme.
public struct DetailHeader: View {
    /// What to show in the center — either a title (with optional icon) or a breadcrumb.
    private let title: DetailHeaderTitle
    /// Which trailing action icons to display.
    private let actions: DetailHeaderActions
    /// Called when the back chevron is tapped.
    private let onBack: () -> Void
    /// Called with the tapped action when a trailing action icon is tapped.
    private let onAction: (DetailHeaderActions) -> Void

    /// Creates a detail header.
    /// - Parameters:
    ///   - title: What to display in the center of the header.
    ///   - actions: Which trailing action icons to show. Defaults to `[.bookmark, .link]`.
    ///   - onBack: Called when the back button is tapped.
    ///   - onAction: Called with the relevant action when a trailing icon is tapped. Defaults to a no-op.
    public init(
        title: DetailHeaderTitle,
        actions: DetailHeaderActions = [.bookmark, .link],
        onBack: @escaping () -> Void,
        onAction: @escaping (DetailHeaderActions) -> Void = { _ in }
    ) {
        self.title = title; self.actions = actions
        self.onBack = onBack; self.onAction = onAction
    }

    public var body: some View {
        HStack(spacing: DSLayout.spacing) {
            Button(action: onBack) { Image(systemName: "chevron.left") }
                .accessibilityLabel("Back")
            Spacer()
            titleView
            Spacer()
            if actions.contains(.rules) {
                Button { onAction(.rules) } label: {
                    Text("Rules").font(DSFont.caption.bold())
                }
                .accessibilityLabel("Rules")
            }
            if actions.contains(.discuss) { actionButton("bubble.left", .discuss, "Comments and activity") }
            if actions.contains(.code) { actionButton("chevron.left.forwardslash.chevron.right", .code, "Embed") }
            if actions.contains(.bookmark) { actionButton("bookmark", .bookmark, "Bookmark") }
            if actions.contains(.link) { actionButton("link", .link, "Share link") }
        }
        .font(DSFont.title3)
        .foregroundStyle(DSColor.textPrimary)
        .padding(.horizontal, DSLayout.margin)
        .padding(.vertical, DSLayout.spacingMedium)
        .buttonStyle(.plain)
    }

    /// Renders the center of the header according to `title`: either an icon +
    /// text title, or a smaller breadcrumb-style label.
    @ViewBuilder
    private var titleView: some View {
        switch title {
        case .text(let s, let iconURL):
            HStack(spacing: DSLayout.spacingSmall) {
                if let iconURL {
                    AsyncImage(url: iconURL) { $0.resizable().scaledToFill() } placeholder: { DSColor.surfaceElevated }
                        .frame(width: DSLayout.spacingXLarge, height: DSLayout.spacingXLarge)
                        .clipShape(RoundedRectangle(cornerRadius: DSLayout.spacingXSmall))
                }
                Text(s).font(DSFont.headline).foregroundStyle(DSColor.textPrimary)
            }
        case .breadcrumb(let s):
            Text(s).font(DSFont.subheadline).foregroundStyle(DSColor.textSecondary)
        }
    }

    /// Builds a single trailing icon button that reports `action` via `onAction`
    /// when tapped.
    /// - Parameters:
    ///   - systemName: The SF Symbol name to display.
    ///   - action: Which action this button represents.
    ///   - label: The accessibility label for VoiceOver users.
    private func actionButton(_ systemName: String, _ action: DetailHeaderActions, _ label: String) -> some View {
        Button { onAction(action) } label: { Image(systemName: systemName) }
            .accessibilityLabel(label)
    }
}
