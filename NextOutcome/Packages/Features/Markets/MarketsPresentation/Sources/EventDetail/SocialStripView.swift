import SwiftUI
import MarketsDomain
import SharedDomain
import DesignSystem

/// The Comments · Top Holders · Positions · Activity strip below an event's rules.
public struct SocialStripView: View {
    /// The view model driving the tabs and their lazy loading.
    @State private var viewModel: SocialStripViewModel
    /// Positions tab UI-only filters (no real position data source yet — see
    /// `PositionsEmptyState`; kept local since they don't drive a fetch).
    @State private var positionsStatus: PositionsStatusFilter = .all
    @State private var positionsSort: PositionsSortFilter = .desc

    /// Creates the view.
    /// - Parameter viewModel: The social-strip view model.
    public init(viewModel: SocialStripViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSLayout.spacing) {
            tabStrip
            filterRow
            content
        }
        .task(id: viewModel.selectedTab) {
            await viewModel.loadIfNeeded(viewModel.selectedTab)
            if viewModel.selectedTab == .activity {
                viewModel.startActivityPolling()
            } else {
                viewModel.stopActivityPolling()
            }
        }
        .onDisappear { viewModel.stopActivityPolling() }
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

    /// The per-tab filter controls shown above the tab's content.
    @ViewBuilder
    private var filterRow: some View {
        switch viewModel.selectedTab {
        case .comments:
            HStack(spacing: 8) {
                Menu {
                    Button("Newest") { viewModel.commentSort = .newest }
                    Button("Most liked") { viewModel.commentSort = .mostLiked }
                } label: {
                    SocialMenuLabel(viewModel.commentSort == .newest ? "Newest" : "Most liked")
                }
                Button {
                    viewModel.commentsHoldersOnly.toggle()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: viewModel.commentsHoldersOnly ? "checkmark.square.fill" : "square")
                        Text("Holders")
                    }
                    .font(DSFont.caption).foregroundStyle(DSColor.textSecondary)
                }
                .buttonStyle(.plain)
                Spacer()
            }
        case .holders:
            if !viewModel.candidates.isEmpty {
                HStack { candidatePicker; Spacer() }
            }
        case .positions:
            HStack(spacing: 8) {
                if !viewModel.candidates.isEmpty { candidatePicker }
                Menu {
                    ForEach(PositionsStatusFilter.allCases, id: \.self) { s in
                        Button(s.title) { positionsStatus = s }
                    }
                } label: { SocialMenuLabel(positionsStatus.title) }
                Menu {
                    ForEach(PositionsSortFilter.allCases, id: \.self) { s in
                        Button(s.title) { positionsSort = s }
                    }
                } label: { SocialMenuLabel(positionsSort.title) }
                Spacer()
            }
        case .activity:
            HStack(spacing: 8) {
                if !viewModel.candidates.isEmpty { activityCandidatePicker }
                Menu {
                    ForEach(ActivityMinAmount.allCases, id: \.title) { option in
                        Button(option.title) { viewModel.activityMinAmount = option }
                    }
                } label: { SocialMenuLabel("Min amount: \(viewModel.activityMinAmount.title)") }
                Spacer()
                Label("Live", systemImage: "circle.fill")
                    .font(DSFont.caption.bold())
                    .foregroundStyle(DSColor.negative)
            }
        }
    }

    /// The candidate (per-country/outcome) picker shared by Holders/Positions.
    private var candidatePicker: some View {
        Menu {
            ForEach(viewModel.candidates) { candidate in
                Button(candidate.title) { viewModel.selectedCandidateID = candidate.id }
            }
        } label: {
            SocialMenuLabel(viewModel.candidates.first { $0.id == viewModel.selectedCandidateID }?.title ?? "Select")
        }
    }

    /// Activity's own candidate picker, with an "All" option (merges every candidate's
    /// trades) that Holders/Positions don't offer — Activity defaults to it.
    private var activityCandidatePicker: some View {
        Menu {
            Button("All") { viewModel.selectedActivityCandidateID = nil }
            ForEach(viewModel.candidates) { candidate in
                Button(candidate.title) { viewModel.selectedActivityCandidateID = candidate.id }
            }
        } label: {
            SocialMenuLabel(viewModel.candidates.first { $0.id == viewModel.selectedActivityCandidateID }?.title ?? "All")
        }
    }

    /// The body for the selected tab (comments/holders/positions/activity).
    @ViewBuilder
    private var content: some View {
        switch viewModel.selectedTab {
        case .comments:
            CommentsTabContent(
                state: viewModel.commentsState,
                fetchHoldings: { await viewModel.commenterHoldings(proxyWallet: $0) },
                candidateTitle: { viewModel.candidateTitle(for: $0) },
                onRetry: { await viewModel.retry(.comments) }
            )
        case .holders:
            HoldersTabContent(state: viewModel.holdersState) { await viewModel.retry(.holders) }
        case .positions:
            PositionsEmptyState()
        case .activity:
            ActivityTabContent(trades: viewModel.visibleActivityTrades, state: viewModel.activityState) { await viewModel.retry(.activity) }
        }
    }
}

// MARK: - Positions UI-only filters

/// Positions tab status filter. UI-only until real position data is available.
private enum PositionsStatusFilter: CaseIterable {
    case all, open, closed
    var title: String {
        switch self {
        case .all: return "All"
        case .open: return "Open"
        case .closed: return "Closed"
        }
    }
}

/// Positions tab sort direction. UI-only until real position data is available.
private enum PositionsSortFilter: CaseIterable {
    case desc, asc
    var title: String { self == .desc ? "Desc" : "Asc" }
}

/// A capsule label used as the tappable label for the social-strip's filter menus.
private struct SocialMenuLabel: View {
    let title: String
    init(_ title: String) { self.title = title }
    var body: some View {
        HStack(spacing: 6) { Text(title); Image(systemName: "chevron.down") }
            .font(DSFont.caption).foregroundStyle(DSColor.textPrimary)
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(DSColor.surface).clipShape(Capsule())
    }
}

// MARK: - Comments

/// The comments tab body: renders loading/empty/error or a list of `CommentRow`s.
private struct CommentsTabContent: View {
    /// The comments load state to render.
    let state: LoadState<[Comment]>
    /// Loads a commenter's positions in this event, for the holder badge.
    let fetchHoldings: (String) async -> [CommentHolding]
    /// Resolves a holding to its candidate's display name.
    let candidateTitle: (CommentHolding) -> String
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
                ForEach(comments) {
                    CommentRow(comment: $0, fetchHoldings: fetchHoldings, candidateTitle: candidateTitle)
                }
            }
        }
    }
}

/// A single comment: avatar, author + relative time + holder badge, and the body text.
/// The badge is lazily loaded per-row (only commenters who hold a position get one) and,
/// when tapped, expands to list every position the commenter holds in this event.
private struct CommentRow: View {
    /// The comment to render.
    let comment: Comment
    /// Loads a commenter's positions in this event, for the holder badge.
    let fetchHoldings: (String) async -> [CommentHolding]
    /// Resolves a holding to its candidate's display name (e.g. "France").
    let candidateTitle: (CommentHolding) -> String

    /// The commenter's holdings, once loaded. `nil` before the lazy fetch completes.
    @State private var holdings: [CommentHolding]?
    /// Whether the full holdings list is expanded below the compact badge.
    @State private var isExpanded = false

    var body: some View {
        HStack(alignment: .top, spacing: DSLayout.spacing) {
            avatar
            VStack(alignment: .leading, spacing: DSLayout.spacingXSmall) {
                HStack(spacing: DSLayout.spacingXSmall) {
                    Text(comment.authorName)
                        .font(DSFont.subheadline.bold())
                        .foregroundStyle(DSColor.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    holderBadge
                    if let createdAt = comment.createdAt {
                        Text(createdAt.formatted(.relative(presentation: .numeric)))
                            .font(DSFont.caption2)
                            .foregroundStyle(DSColor.textSecondary)
                    }
                }
                if isExpanded, let holdings {
                    holdingsList(holdings)
                }
                Text(comment.body)
                    .font(DSFont.body)
                    .foregroundStyle(DSColor.textPrimary)
                if comment.likeCount > 0 {
                    Label("\(comment.likeCount)", systemImage: "heart")
                        .font(DSFont.caption2)
                        .foregroundStyle(DSColor.textSecondary)
                }
            }
        }
        .task(id: comment.proxyWallet) {
            guard let proxyWallet = comment.proxyWallet else { return }
            holdings = await fetchHoldings(proxyWallet)
        }
    }

    /// The largest holding, by shares — what the compact badge summarizes.
    private var topHolding: CommentHolding? {
        holdings?.max { $0.size < $1.size }
    }

    /// The compact "1.7K France" badge, shown once holdings load and the commenter holds
    /// at least one position. Tapping toggles the full `holdingsList` below.
    @ViewBuilder
    private var holderBadge: some View {
        if let topHolding {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 4) {
                    Text("\(MarketFormatting.compactShares(topHolding.size)) \(candidateTitle(topHolding))")
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                }
                .font(DSFont.caption2.bold())
                .foregroundStyle(DSColor.positive)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(DSColor.positiveTint)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    /// The commenter's full position list, one row per market held, shown when expanded.
    private func holdingsList(_ holdings: [CommentHolding]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(holdings.sorted { $0.size > $1.size }) { holding in
                HStack(spacing: 6) {
                    Text(candidateTitle(holding))
                        .font(DSFont.caption)
                        .foregroundStyle(DSColor.textPrimary)
                    Spacer(minLength: DSLayout.spacing)
                    Text("\(MarketFormatting.compactShares(holding.size)) \(holding.outcome)")
                        .font(DSFont.caption.bold())
                        .foregroundStyle(DSColor.positive)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(DSColor.positiveTint)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(DSLayout.spacingSmall)
        .background(DSColor.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: DSLayout.chipRadius))
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
    /// The (already min-amount-filtered) trades to render.
    let trades: [ActivityTrade]
    /// The activity load state (drives loading/empty/error; `trades` supplies `.loaded` rows).
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
        case .loaded:
            if trades.isEmpty {
                EmptyRow(text: "No activity above this amount.")
            } else {
                VStack(alignment: .leading, spacing: DSLayout.spacing) {
                    ForEach(trades) { ActivityTradeRow(trade: $0) }
                }
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
