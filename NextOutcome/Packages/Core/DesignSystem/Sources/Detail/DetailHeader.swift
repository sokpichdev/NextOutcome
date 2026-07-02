import SwiftUI

public enum DetailHeaderTitle {
    case text(String, iconURL: URL?)
    case breadcrumb(String)
}

public struct DetailHeaderActions: OptionSet {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let code     = DetailHeaderActions(rawValue: 1 << 0)
    public static let bookmark = DetailHeaderActions(rawValue: 1 << 1)
    public static let link     = DetailHeaderActions(rawValue: 1 << 2)
}

/// Custom back-button header for pushed detail screens (native nav bar hidden).
public struct DetailHeader: View {
    private let title: DetailHeaderTitle
    private let actions: DetailHeaderActions
    private let onBack: () -> Void
    private let onAction: (DetailHeaderActions) -> Void

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
            if actions.contains(.code) { actionButton("chevron.left.forwardslash.chevron.right", .code, "Embed") }
            if actions.contains(.bookmark) { actionButton("bookmark", .bookmark, "Bookmark") }
            if actions.contains(.link) { actionButton("link", .link, "Share link") }
        }
        .font(.title3)
        .foregroundStyle(DSColor.textPrimary)
        .padding(.horizontal, DSLayout.margin)
        .padding(.vertical, 10)
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var titleView: some View {
        switch title {
        case .text(let s, let iconURL):
            HStack(spacing: 8) {
                if let iconURL {
                    AsyncImage(url: iconURL) { $0.resizable().scaledToFill() } placeholder: { DSColor.surfaceElevated }
                        .frame(width: 24, height: 24).clipShape(RoundedRectangle(cornerRadius: 6))
                }
                Text(s).font(DSFont.headline).foregroundStyle(DSColor.textPrimary)
            }
        case .breadcrumb(let s):
            Text(s).font(DSFont.subheadline).foregroundStyle(DSColor.textSecondary)
        }
    }

    private func actionButton(_ systemName: String, _ action: DetailHeaderActions, _ label: String) -> some View {
        Button { onAction(action) } label: { Image(systemName: systemName) }
            .accessibilityLabel(label)
    }
}
