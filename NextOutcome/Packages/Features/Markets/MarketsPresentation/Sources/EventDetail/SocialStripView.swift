import SwiftUI
import MarketsDomain
import SharedDomain
import DesignSystem

/// The Comments · Top Holders · Positions · Activity strip below an event's rules.
public struct SocialStripView: View {
    /// The view model driving the tabs and their lazy loading.
    @State private var viewModel: SocialStripViewModel

    /// Creates the view.
    /// - Parameter viewModel: The social-strip view model.
    public init(viewModel: SocialStripViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSLayout.spacing) {
            tabStrip
            content
        }
        .task(id: viewModel.selectedTab) {
            await viewModel.loadIfNeeded(viewModel.selectedTab)
        }
    }

    /// The chip row of tab titles.
    private var tabStrip: some View {
        ChipRow(items: SocialTab.allCases.map(\.title), selection: selectionBinding)
    }

    /// Bridges the chip row's `Int` selection to the view model's `SocialTab`.
    private var selectionBinding: Binding<Int> {
        Binding(
            get: { SocialTab.allCases.firstIndex(of: viewModel.selectedTab) ?? 0 },
            set: { index in
                guard SocialTab.allCases.indices.contains(index) else { return }
                viewModel.selectedTab = SocialTab.allCases[index]
            }
        )
    }

    /// The body for the selected tab (comments/holders/positions/activity).
    @ViewBuilder
    private var content: some View {
        switch viewModel.selectedTab {
        case .comments:
            CommentsTabContent(state: viewModel.commentsState) { await viewModel.retry(.comments) }
        case .holders:
            HoldersTabContent(state: viewModel.holdersState) { await viewModel.retry(.holders) }
        case .positions:
            PositionsEmptyState()
        case .activity:
            ActivityTabContent(state: viewModel.activityState) { await viewModel.retry(.activity) }
        }
    }
}

// MARK: - Comments

/// The comments tab body: renders loading/empty/error or a list of `CommentRow`s.
private struct CommentsTabContent: View {
    /// The comments load state to render.
    let state: LoadState<[Comment]>
    /// Retry action for the error state.
    let onRetry: () async -> Void

    var body: some View {
        switch state {
        case .idle, .loading:
            ProgressView().tint(DSColor.accent).frame(maxWidth: .infinity).padding(.vertical, DSLayout.spacingLarge)
        case .empty:
            EmptyRow(text: "No comments yet.")
        case .failed(let message):
            RetryRow(message: message, onRetry: onRetry)
        case .loaded(let comments):
            VStack(alignment: .leading, spacing: DSLayout.spacing) {
                ForEach(comments) { CommentRow(comment: $0) }
            }
        }
    }
}

/// A single comment: avatar, author + relative time, and the body text.
private struct CommentRow: View {
    /// The comment to render.
    let comment: Comment

    var body: some View {
        HStack(alignment: .top, spacing: DSLayout.spacing) {
            avatar
            VStack(alignment: .leading, spacing: DSLayout.spacingXSmall) {
                HStack(spacing: DSLayout.spacingXSmall) {
                    Text(comment.authorName)
                        .font(DSFont.subheadline.bold())
                        .foregroundStyle(DSColor.textPrimary)
                    if let createdAt = comment.createdAt {
                        Text(createdAt.formatted(.relative(presentation: .numeric)))
                            .font(DSFont.caption2)
                            .foregroundStyle(DSColor.textSecondary)
                    }
                }
                Text(comment.body)
                    .font(DSFont.body)
                    .foregroundStyle(DSColor.textPrimary)
            }
        }
    }

    /// The commenter's circular avatar, or a placeholder circle when there's no image.
    @ViewBuilder
    private var avatar: some View {
        if let url = comment.avatarURL {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                DSColor.surfaceElevated
            }
            .frame(width: 32, height: 32)
            .clipShape(Circle())
        } else {
            Circle().fill(DSColor.surfaceElevated).frame(width: 32, height: 32)
        }
    }
}

// MARK: - Top Holders

/// The holders tab body: renders loading/empty/error or a ranked list of `HolderRankRow`s.
private struct HoldersTabContent: View {
    /// The holders load state to render.
    let state: LoadState<[Holder]>
    /// Retry action for the error state.
    let onRetry: () async -> Void

    var body: some View {
        switch state {
        case .idle, .loading:
            ProgressView().tint(DSColor.accent).frame(maxWidth: .infinity).padding(.vertical, DSLayout.spacingLarge)
        case .empty:
            EmptyRow(text: "No holder data.")
        case .failed(let message):
            RetryRow(message: message, onRetry: onRetry)
        case .loaded(let holders):
            VStack(alignment: .leading, spacing: DSLayout.spacing) {
                ForEach(Array(holders.enumerated()), id: \.element.id) { index, holder in
                    HolderRankRow(rank: index + 1, holder: holder)
                }
            }
        }
    }
}

/// One ranked holder row: rank, avatar, name, outcome badge, and shares.
private struct HolderRankRow: View {
    /// The 1-based rank.
    let rank: Int
    /// The holder to render.
    let holder: Holder

    var body: some View {
        HStack(spacing: DSLayout.spacing) {
            Text("\(rank)")
                .font(DSFont.caption.bold())
                .foregroundStyle(DSColor.textSecondary)
                .frame(width: 20, alignment: .leading)
            avatar
            Text(holder.name)
                .font(DSFont.subheadline)
                .foregroundStyle(DSColor.textPrimary)
                .lineLimit(1)
            if !holder.outcome.isEmpty {
                StatusBadge(holder.outcome, color: holder.outcome == "Yes" ? DSColor.positive : DSColor.negative)
            }
            Spacer()
            Text(sharesText)
                .font(DSFont.caption.bold())
                .foregroundStyle(DSColor.textSecondary)
        }
    }

    /// The holder's shares formatted compactly with K/M suffixes.
    private var sharesText: String {
        let value = NSDecimalNumber(decimal: holder.shares).doubleValue
        switch value {
        case 1_000_000...: return String(format: "%.1fM", value / 1_000_000)
        case 1_000...: return String(format: "%.1fK", value / 1_000)
        default: return String(Int(value.rounded()))
        }
    }

    /// The holder's circular avatar, or a placeholder circle when there's no image.
    @ViewBuilder
    private var avatar: some View {
        if let url = holder.profileImageURL {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                DSColor.surfaceElevated
            }
            .frame(width: 28, height: 28)
            .clipShape(Circle())
        } else {
            Circle().fill(DSColor.surfaceElevated).frame(width: 28, height: 28)
        }
    }
}

// MARK: - Positions (static empty state)

/// The static "no positions" placeholder for the Positions tab (real data arrives later).
private struct PositionsEmptyState: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DSLayout.spacingSmall) {
            Text("No positions to show")
                .font(DSFont.subheadline.bold())
                .foregroundStyle(DSColor.textPrimary)
            Text("Sign-in and funding arrive in a later release of NextOutcome.")
                .font(DSFont.caption)
                .foregroundStyle(DSColor.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, DSLayout.spacingLarge)
    }
}

// MARK: - Activity

/// The activity tab body: renders loading/empty/error or a list of `ActivityTradeRow`s.
private struct ActivityTabContent: View {
    /// The activity load state to render.
    let state: LoadState<[ActivityTrade]>
    /// Retry action for the error state.
    let onRetry: () async -> Void

    var body: some View {
        switch state {
        case .idle, .loading:
            ProgressView().tint(DSColor.accent).frame(maxWidth: .infinity).padding(.vertical, DSLayout.spacingLarge)
        case .empty:
            EmptyRow(text: "No activity yet.")
        case .failed(let message):
            RetryRow(message: message, onRetry: onRetry)
        case .loaded(let trades):
            VStack(alignment: .leading, spacing: DSLayout.spacing) {
                ForEach(trades) { ActivityTradeRow(trade: $0) }
            }
        }
    }
}

/// One activity trade row: side badge, actor + outcome, and size + relative time.
private struct ActivityTradeRow: View {
    /// The trade to render.
    let trade: ActivityTrade

    var body: some View {
        HStack(spacing: DSLayout.spacing) {
            StatusBadge(trade.side.label, color: sideColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(trade.actorName)
                    .font(DSFont.subheadline)
                    .foregroundStyle(DSColor.textPrimary)
                    .lineLimit(1)
                if !trade.outcome.isEmpty {
                    Text(trade.outcome)
                        .font(DSFont.caption)
                        .foregroundStyle(DSColor.textSecondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(sizeText)
                    .font(DSFont.caption.bold())
                    .foregroundStyle(sideColor)
                Text(trade.timestamp.formatted(.relative(presentation: .numeric)))
                    .font(DSFont.caption2)
                    .foregroundStyle(DSColor.textSecondary)
            }
        }
    }

    /// Green for a buy, red for a sell.
    private var sideColor: Color {
        trade.side == .buy ? DSColor.positive : DSColor.negative
    }

    /// The trade size formatted compactly with K/M suffixes.
    private var sizeText: String {
        let value = NSDecimalNumber(decimal: trade.size).doubleValue
        switch value {
        case 1_000_000...: return String(format: "%.1fM", value / 1_000_000)
        case 1_000...: return String(format: "%.1fK", value / 1_000)
        default: return String(Int(value.rounded()))
        }
    }
}

// MARK: - Shared row helpers

/// A simple muted one-line empty-state row shared by the tabs.
private struct EmptyRow: View {
    /// The message to show.
    let text: String

    var body: some View {
        Text(text)
            .font(DSFont.caption)
            .foregroundStyle(DSColor.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, DSLayout.spacing)
    }
}

/// Inline retry row — every tab's `.failed` state renders this, never a blank section.
private struct RetryRow: View {
    /// The error message to show.
    let message: String
    /// The retry action.
    let onRetry: () async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DSLayout.spacingSmall) {
            Text(message)
                .font(DSFont.caption)
                .foregroundStyle(DSColor.textSecondary)
            Button("Retry") { Task { await onRetry() } }
                .font(DSFont.caption.bold())
                .foregroundStyle(DSColor.accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, DSLayout.spacing)
    }
}
