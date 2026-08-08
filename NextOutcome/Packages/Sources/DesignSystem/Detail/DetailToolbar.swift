import SwiftUI

/// The set of trailing toolbar actions a detail screen can show (embed/code,
/// bookmark, share link, rules, discuss). Conforms to `OptionSet` so callers can combine
/// any subset, e.g. `[.bookmark, .link]`.
public struct DetailToolbarActions: OptionSet {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    /// Shows an "embed"/code icon button (e.g. for embedding a chart elsewhere).
    public static let code     = DetailToolbarActions(rawValue: 1 << 0)
    /// Shows a bookmark/save icon button.
    public static let bookmark = DetailToolbarActions(rawValue: 1 << 1)
    /// Shows a share-link icon button.
    public static let link     = DetailToolbarActions(rawValue: 1 << 2)
    /// Shows a "Rules" text button (opens the rules bottom sheet).
    public static let rules    = DetailToolbarActions(rawValue: 1 << 3)
    /// Shows a discussion/comment-bubble icon button (opens the Comments/Top
    /// Holders/Positions/Activity bottom sheet).
    public static let discuss  = DetailToolbarActions(rawValue: 1 << 4)
}

/// Applies a dark-styled native navigation bar to a pushed detail screen — a small,
/// secondary-styled title (matching the live site's breadcrumb-over-big-title layout,
/// where the real headline lives in the scroll content below) plus the given trailing
/// actions, all rendered through real `ToolbarItem`s instead of a hand-drawn header bar.
public struct DetailToolbar: ViewModifier {
    /// The breadcrumb-style title shown in the center of the bar.
    private let title: String
    /// An optional small icon shown before the title (e.g. a market's category icon).
    private let iconURL: URL?
    /// Which trailing action icons to display.
    private let actions: DetailToolbarActions
    /// Called with the tapped action.
    private let onAction: (DetailToolbarActions) -> Void

    /// Creates the toolbar modifier.
    /// - Parameters:
    ///   - title: The breadcrumb-style title.
    ///   - iconURL: An optional icon shown before the title.
    ///   - actions: Which trailing action icons to show.
    ///   - onAction: Called with the relevant action when a trailing icon is tapped.
    public init(title: String, iconURL: URL? = nil, actions: DetailToolbarActions, onAction: @escaping (DetailToolbarActions) -> Void) {
        self.title = title
        self.iconURL = iconURL
        self.actions = actions
        self.onAction = onAction
    }

    public func body(content: Content) -> some View {
        content
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(DSColor.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            #endif
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: DSLayout.spacingSmall) {
                        if let iconURL {
                            AsyncImage(url: iconURL) { $0.resizable().scaledToFill() } placeholder: { DSColor.surfaceElevated }
                                .frame(width: DSLayout.spacingXLarge, height: DSLayout.spacingXLarge)
                                .clipShape(RoundedRectangle(cornerRadius: DSLayout.spacingXSmall))
                        }
                        Text(title)
                            .font(iconURL == nil ? DSFont.subheadline : DSFont.headline)
                            .foregroundStyle(iconURL == nil ? DSColor.textSecondary : DSColor.textPrimary)
                            .lineLimit(1)
                    }
                }
                #if os(iOS)
                ToolbarItemGroup(placement: .navigationBarTrailing) { trailingActions }
                #else
                ToolbarItemGroup(placement: .automatic) { trailingActions }
                #endif
            }
            .tint(DSColor.textPrimary)
    }

    /// The trailing action buttons, shared across platforms (only their toolbar
    /// placement differs).
    @ViewBuilder
    private var trailingActions: some View {
        if actions.contains(.rules) {
            Button("Rules") { onAction(.rules) }
                .font(DSFont.caption.bold())
                .accessibilityLabel("Rules")
        }
        if actions.contains(.discuss) {
            Button { onAction(.discuss) } label: { Image(systemName: "bubble.left") }
                .accessibilityLabel("Comments and activity")
        }
        if actions.contains(.code) {
            Button { onAction(.code) } label: { Image(systemName: "chevron.left.forwardslash.chevron.right") }
                .accessibilityLabel("Embed")
        }
        if actions.contains(.bookmark) {
            Button { onAction(.bookmark) } label: { Image(systemName: "bookmark") }
                .accessibilityLabel("Bookmark")
        }
        if actions.contains(.link) {
            Button { onAction(.link) } label: { Image(systemName: "link") }
                .accessibilityLabel("Share link")
        }
    }
}

public extension View {
    /// Applies the app's dark-styled native detail-screen navigation bar.
    /// - Parameters:
    ///   - title: The breadcrumb-style title shown centered in the bar.
    ///   - iconURL: An optional icon shown before the title (e.g. a market's category icon).
    ///   - actions: Which trailing action icons to show.
    ///   - onAction: Called with the relevant action when a trailing icon is tapped. Defaults to a no-op.
    func detailToolbar(
        title: String,
        iconURL: URL? = nil,
        actions: DetailToolbarActions,
        onAction: @escaping (DetailToolbarActions) -> Void = { _ in }
    ) -> some View {
        modifier(DetailToolbar(title: title, iconURL: iconURL, actions: actions, onAction: onAction))
    }
}
