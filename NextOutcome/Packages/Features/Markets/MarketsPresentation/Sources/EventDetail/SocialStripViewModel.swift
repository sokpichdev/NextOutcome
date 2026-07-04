import Foundation
import MarketsDomain
import SharedDomain

/// The four inner tabs of an event's social strip.
public enum SocialTab: String, CaseIterable, Sendable {
    case comments, holders, positions, activity

    /// The tab's display title.
    public var title: String {
        switch self {
        case .comments: return "Comments"
        case .holders: return "Top Holders"
        case .positions: return "Positions"
        case .activity: return "Activity"
        }
    }
}

/// Drives the Comments · Top Holders · Positions · Activity strip below an event's rules.
/// Each tab fetches lazily, only on its first visit — `Positions` never fetches; it's a
/// static empty state (portfolio data arrives in a later release).
@MainActor
@Observable
public final class SocialStripViewModel {
    /// The currently-selected inner tab.
    public var selectedTab: SocialTab = .comments
    /// The comments tab's load state.
    public private(set) var commentsState: LoadState<[Comment]> = .idle
    /// The holders tab's load state.
    public private(set) var holdersState: LoadState<[Holder]> = .idle
    /// The activity tab's load state.
    public private(set) var activityState: LoadState<[ActivityTrade]> = .idle

    /// The event whose comments are fetched.
    private let eventID: String
    /// The top market's condition id (for holders/activity); may be `nil`.
    private let conditionId: String?
    /// Use case that fetches comments.
    private let fetchComments: FetchCommentsUseCase
    /// Use case that fetches holders.
    private let fetchHolders: FetchHoldersUseCase
    /// Use case that fetches activity trades.
    private let fetchActivity: FetchActivityTradesUseCase

    /// Creates the view model.
    /// - Parameters:
    ///   - eventID: The event whose comments to fetch.
    ///   - conditionId: The market condition for holders/activity, if any.
    ///   - fetchComments: Comments use case.
    ///   - fetchHolders: Holders use case.
    ///   - fetchActivity: Activity-trades use case.
    public init(
        eventID: String,
        conditionId: String?,
        fetchComments: FetchCommentsUseCase,
        fetchHolders: FetchHoldersUseCase,
        fetchActivity: FetchActivityTradesUseCase
    ) {
        self.eventID = eventID
        self.conditionId = conditionId
        self.fetchComments = fetchComments
        self.fetchHolders = fetchHolders
        self.fetchActivity = fetchActivity
    }

    /// Fetches `tab`'s content if it hasn't already started loading. Safe to call every
    /// time a tab is shown — a view should call this from `.task(id: selectedTab)`.
    public func loadIfNeeded(_ tab: SocialTab) async {
        switch tab {
        case .comments:
            guard case .idle = commentsState else { return }
            commentsState = .loading
            do {
                let items = try await fetchComments.execute(eventID: eventID)
                commentsState = items.isEmpty ? .empty : .loaded(items)
            } catch {
                commentsState = isCancellation(error)
                    ? .idle
                    : .failed(message: "Couldn't load comments. Check your connection and try again.")
            }
        case .holders:
            guard case .idle = holdersState else { return }
            guard let conditionId, !conditionId.isEmpty else { holdersState = .empty; return }
            holdersState = .loading
            do {
                let items = try await fetchHolders.execute(conditionId: conditionId)
                holdersState = items.isEmpty ? .empty : .loaded(items)
            } catch {
                holdersState = isCancellation(error)
                    ? .idle
                    : .failed(message: "Couldn't load top holders. Check your connection and try again.")
            }
        case .positions:
            return // static empty-state; never fetches
        case .activity:
            guard case .idle = activityState else { return }
            guard let conditionId, !conditionId.isEmpty else { activityState = .empty; return }
            activityState = .loading
            do {
                let items = try await fetchActivity.execute(conditionId: conditionId)
                activityState = items.isEmpty ? .empty : .loaded(items)
            } catch {
                activityState = isCancellation(error)
                    ? .idle
                    : .failed(message: "Couldn't load activity. Check your connection and try again.")
            }
        }
    }

    /// A cancelled fetch (e.g. from a `.task(id: selectedTab)` restart on rapid tab
    /// switching) is not a network failure — it must reset the tab to `.idle` so the
    /// next visit refetches, instead of showing a false "connection error" retry row.
    private func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        if (error as? URLError)?.code == .cancelled { return true }
        return Task.isCancelled
    }

    /// Resets `tab`'s state to `.idle` and re-fetches. Used by the inline retry row.
    public func retry(_ tab: SocialTab) async {
        switch tab {
        case .comments: commentsState = .idle
        case .holders: holdersState = .idle
        case .activity: activityState = .idle
        case .positions: return
        }
        await loadIfNeeded(tab)
    }
}
